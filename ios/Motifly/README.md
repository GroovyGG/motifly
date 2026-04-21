# Motifly (iOS)

Open **`Motifly.xcodeproj`** in this directory in Xcode 16+ (use **File → Open** if double-click does not work).

**Seed data:** canonical CSVs live in the repo at **`../../data_seed/`** (`seed_nouns`, `seed_verbs`, `seed_adjectives`, `seed_adv`). The app bundles copies under **`SeedData/`** next to the source tree; update those files when you change seeds, or re-copy from `data_seed/` before shipping.

- **Home:** empty shell (v1.0).
- **Vocabulary:** search and bundled CSV import from `SeedData/`; up to 50 recent searches (SwiftData). Opens noun, verb, adjective, or adverb cards by entry kind.
- **Dictation:** words in units of 50 by `seedNumber` order; session uses English gloss prompt and lemma typing.

Build from CLI:

```bash
xcodebuild -project Motifly.xcodeproj -target Motifly -sdk iphonesimulator -configuration Debug build
```

Set your **Development Team** in the Motifly target for device runs.
