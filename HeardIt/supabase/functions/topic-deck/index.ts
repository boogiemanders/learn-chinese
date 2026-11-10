// Supabase edge function: POST {"topic": "Lingnan brush painting"} and get back a
// Hear to Read topic deck — the 20–25 words a learner needs for that topic, with
// simplified and traditional characters, pinyin and Jyutping.
//
// Deploy:   supabase functions deploy topic-deck
// Secret:   supabase secrets set ANTHROPIC_API_KEY=...   (set it yourself; never commit it)
// The app calls https://<project>.supabase.co/functions/v1/topic-deck with the
// project's public anon key (Info.plist: HTRTopicEndpoint, HTRTopicKey).

import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic(); // reads ANTHROPIC_API_KEY

const SYSTEM = `You build vocabulary decks for Hear to Read, an app for people who \
already hear some Chinese (often Cantonese at home) and want to read and say the words \
they need. Given a learner's topic or goal, choose the 20 to 25 words or short phrases \
they would most need to talk about it: the core nouns, verbs and one or two everyday \
phrases a practitioner actually says, most useful first. Prefer terms used in both \
Mandarin and Cantonese; when Cantonese speakers say it differently, put the Cantonese \
word and its Jyutping in the note (e.g. "In Cantonese: 睇醫生 tai2 ji1 sang1."). \
Otherwise leave the note empty.

Readings must be exact. pinyin uses tone marks (nǐ hǎo), spaced by word. jyutping is \
the standard LSHK romanisation of the same characters, with tone numbers, one syllable \
per character (nei5 hou2). Give both simplified and traditional forms. meaning is short \
plain English (under 40 characters).

Also name the deck: title is 1–3 English words, hanzi is exactly two Chinese characters \
for a brush-written heading, label is exactly four Chinese characters describing the \
deck, tag is one English word in capitals, line is 2–4 capitalised words joined by " · ".

If the topic is not something a person could learn vocabulary for, or would need \
harmful content, return an empty words list.`;

const schema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "hanzi", "label", "tag", "line", "words"],
  properties: {
    title: { type: "string" },
    hanzi: { type: "string" },
    label: { type: "string" },
    tag: { type: "string" },
    line: { type: "string" },
    words: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["simplified", "traditional", "pinyin", "jyutping", "meaning", "note"],
        properties: {
          simplified: { type: "string" },
          traditional: { type: "string" },
          pinyin: { type: "string" },
          jyutping: { type: "string" },
          meaning: { type: "string" },
          note: { type: "string" },
        },
      },
    },
  },
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  let topic = "";
  try {
    topic = String((await req.json()).topic ?? "").trim().slice(0, 80);
  } catch {
    return json({ error: "Send JSON like {\"topic\": \"pottery\"}." }, 400);
  }
  if (topic.length < 2) return json({ error: "Tell us a topic first." }, 400);

  try {
    const response = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      output_config: {
        effort: "low", // a word list, not a hard problem; keeps the cost per deck down
        format: { type: "json_schema", schema },
      },
      // if a safety check declines, the API retries on a fallback model in the same call
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: SYSTEM,
      messages: [{ role: "user", content: `Topic: ${topic}` }],
    } as any);

    if (response.stop_reason === "refusal") {
      return json({ error: "We can't make a deck for that topic." }, 422);
    }
    if (response.stop_reason === "max_tokens") {
      return json({ error: "That deck came out too long. Try a narrower topic." }, 502);
    }
    const text = response.content.find((b: { type: string }) => b.type === "text") as { text: string } | undefined;
    if (!text) return json({ error: "No words came back. Try again." }, 502);

    const deck = JSON.parse(text.text);
    if (!Array.isArray(deck.words) || deck.words.length === 0) {
      return json({ error: "We can't make a deck for that topic." }, 422);
    }
    deck.words = deck.words.slice(0, 30);
    return json(deck);
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) return json({ error: "Busy right now. Try again in a minute." }, 429);
    if (err instanceof Anthropic.APIConnectionError) return json({ error: "Couldn't reach the word service." }, 503);
    if (err instanceof Anthropic.APIError) return json({ error: "The word service had a problem. Try again." }, 502);
    console.error(err);
    return json({ error: "Something went wrong making that deck." }, 500);
  }
});
