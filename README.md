# learn-chinese

**Heard It** is an iPhone app for heritage speakers, people who understand some Cantonese or Mandarin but can't read it. Flashcards live on the Lock Screen, and you reveal and grade them there without opening the app. Each card shows the characters with both Mandarin pinyin and Cantonese Jyutping, and starts from words you already know by ear.

- Review order: priority = how useful the word is × (1 − mastery) × boosts. Mastery fades on an FSRS-style forgetting curve. Words you missed after marking "Knew it", words you know by ear, and overdue words jump the queue.
- Decks: survival travel, a menu decoder (cooking method + ingredient + cut + flavor), and Cantonese → Mandarin word pairs.
- Pronunciation: Apple's on-device Mandarin (zh-CN) and Cantonese (zh-HK) voices, including a speaker button on the Lock Screen widget.

The app lives in [`HeardIt/`](HeardIt/). See [HeardIt/README.md](HeardIt/README.md) for build steps.

Status: early prototype (v0.1). It builds for the iOS Simulator and hasn't been tested on a device yet.
