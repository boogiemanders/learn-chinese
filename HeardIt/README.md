# Heard It (working name)

Lock-screen Chinese flashcards for people who speak some Cantonese or Mandarin but can't read it. Each card shows characters with pinyin and Jyutping. You can reveal it and grade it (Knew it / Unsure / Missed) right on the Lock Screen.

## What's here

| Path | What it does |
|---|---|
| `project.yml` | XcodeGen spec: iOS 17 app + widget extension sharing one App Group |
| `Shared/Scheduler.swift` | Memory model and ranking: priority = deck weight × (1 − mastery) × boosts. Mastery fades on an FSRS-style curve; unseen words start at a 50/50 prior; boosts for confident misses, words known by ear, and overdue words |
| `Shared/Store.swift` | Progress as one JSON file in the App Group, read by both the app and the widget |
| `Shared/CardIntents.swift` | Reveal and Grade intents behind the widget buttons |
| `Shared/words.json` | 66 hand-made starter words: survival travel, the menu decoder (method + ingredient + cut + flavor), and Cantonese → Mandarin pairs |
| `Widget/HeardItWidget.swift` | Lock Screen rectangular (flip + grade), inline, circular, and Home Screen small widgets |
| `App/` | Today card with Mandarin/Cantonese speech, word list with "known by ear" toggles, settings |
| `Tests/SchedulerCheck/main.swift` | Plain checks for the scheduler and store (run below) |

## Build and run

1. Install Xcode from the Mac App Store, open it once, and add the iOS platform.
2. Point the command-line tools at it: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. In this folder: `xcodegen generate`, then `open HeardIt.xcodeproj`
4. In Xcode, select each target (HeardIt and HeardItWidget). Under **Signing & Capabilities**, choose your Team. If Xcode says the bundle ID or App Group is taken, change `com.anderschan.heardit` in `project.yml` and `Store.appGroupID` in `Shared/Store.swift`, then regenerate.
5. Run on your iPhone. A free Apple ID works, but the app stops opening after 7 days and needs reinstalling.
6. Add the widget: long-press the Lock Screen, tap **Customize**, then **Lock Screen**, then the widget area, and pick **Heard It**.

Check the logic without Xcode:

```bash
swiftc Shared/Word.swift Shared/Scheduler.swift Shared/Store.swift Tests/SchedulerCheck/main.swift -o /tmp/schedcheck && /tmp/schedcheck Shared/words.json
```

## Known limits (v0.1)

- One skill per word (reading recognition). Next step: track Mandarin reading, Cantonese reading, and typing separately.
- Widget buttons on the Lock Screen may ask for Face ID before they run. Test on a real phone.
- Speech uses Apple's zh-CN and zh-HK voices. Listen for words with more than one reading (的, 了, 行).
- Starter words are hand-written. A full deck should come from CC-CEDICT (Mandarin) and CC-Canto (Cantonese), both licensed CC BY-SA. Give them credit and share any edits to their data.
- No app icon yet.
