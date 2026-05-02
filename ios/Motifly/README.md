# Motifly (iOS)

Open **`Motifly.xcodeproj`** in this directory in Xcode 16+ (use **File → Open** if double-click does not work).

**Seed data:** canonical CSVs live in the repo at **`../../data_seed/`** (`seed_nouns`, `seed_verbs`, `seed_adjectives`, `seed_adv`, `seed_determiners`, `seed_pronouns`, `seed_prepositions`).  
The app bundles copies under **`SeedData/`** next to the source tree; update those files when you change seeds, or re-copy from `data_seed/` before shipping.

- **Home:** study dashboard (streak, weekly time/accuracy, study heatmap, group progress, vocabulary progress, daily/weekly goal cards); gear opens **Settings**.
- **Vocabulary:** search and bundled CSV import from `SeedData/`; recent history + typed cards by entry kind (noun/verb/adjective/adverb/determiner/pronoun/preposition), with Mine recording workflow.
- **Dictation:** grouped by assigned range groups (from seed `group assigned`, fallback by seed-number formula); manual/auto playback (`DictationPlaybackEngine`), review flows, per-word `DictationWordStats` (mastery / weakness / next review) updated from attempts.
- **Tool:** utilities hub (`ToolView`); **French pronunciation** opens an IPA chart with filters and example-word TTS.
- **Settings:** goals, theme color, reminders, study preferences, about/debug entry (from Home toolbar).

## Current local data schema (SwiftData)

Registered in `MotiflyApp` schema:

- `VocabularyEntry` — local dictionary rows (all entry kinds), includes `groupAssigned`.
- `SearchHistoryEntry` — recent lookup index (per-seed last searched time).
- `DictationSession` — session lifecycle + summary counts/config snapshot.
- `DictationAttemptLog` — per-attempt event log (`promptShownAt`, `submittedAt`, replay info, correctness, normalized forms).
- `DictationWordStats` — per-word aggregates for the **V1 dictation memory model** (mastery, weakness buckets, next review); updated by `WordMasteryUpdater` after attempts (see `docs/french_dictation_memory_model.md`, `docs/mastery_weakness_next_review.zh.md`).
- `VocabularyStudyEvent` — append-only cross-feature timeline (`eventType`, `occurredAt`, `contextJSON`).

## Study event timeline

`StudyEventLogger` writes append-only `VocabularyStudyEvent` rows for key actions, including:

- card open (`card_view`)
- memory edits (`memory_note_edit`)
- mine recording actions (`mine_saved`, `mine_discarded`)
- dictation session lifecycle and interactions (`dictation_session_start`, `dictation_prompt_play`, `dictation_replay`, `dictation_submit`, `dictation_session_end`)
- dictation progress mirror events (`dictation_progress_completed`, `dictation_progress_abandoned`)
- review interactions (`review_word_open`, `review_tts_play`, `review_mine_play`, `review_start_dictation_tap`)

Notes:

- `contextJSON` is currently generated from a flat `[String: String]` map.
- "Append-only" is a write-path convention in app code, not an immutable-store constraint.
- `DictationProgressStore` remains `UserDefaults`-backed, with lifecycle changes mirrored into `VocabularyStudyEvent`.

Build from CLI:

```bash
xcodebuild -project Motifly.xcodeproj -target Motifly -sdk iphonesimulator -configuration Debug build
```

Set your **Development Team** in the Motifly target for device runs.
