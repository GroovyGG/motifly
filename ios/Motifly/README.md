# Motifly (iOS)

Open `Motifly.xcodeproj` in Xcode 16+ (iOS 17 deployment target).

- **Home:** empty shell (v1.0).
- **Vocabulary:** search bundled `seed_nouns.csv` import; up to 50 recent searches (SwiftData).
- **Dictation:** words in units of 50 by `seedNumber` order; session uses English gloss prompt and lemma typing.

Build from CLI:

```bash
xcodebuild -project Motifly.xcodeproj -target Motifly -sdk iphonesimulator -configuration Debug build
```

Set your **Development Team** in the Motifly target for device runs.
