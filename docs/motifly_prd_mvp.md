# Product Requirements Document  
## motifly

This document describes **two product phases**. **Version 1** is vocabulary- and word-centric. **Version 2** adds sentence-based dictation and grammar features (much of what earlier drafts of this PRD described as “MVP”).

**Platform:** iPhone app  
**Stack:** Swift, SwiftUI, SwiftData (v1); optional server/Postgres alignment with [database_schema.md](database_schema.md) in later phases.

---

## Product phases (overview)

| | **Version 1 — Vocabulary** | **Version 2 — Dictation + grammar** |
|---|---------------------------|-------------------------------------|
| **Focus** | Words, word-type cards (e.g. noun / verb / adjective), translations, example lines, light progress | Sentence dictation (listen → type), answer checking, grammar topics/tags tied to sentences |
| **Primary content unit** | Headword + card metadata + example sentence (for context, not necessarily graded dictation) | Sentence as practice unit; typed dictation against full French line |
| **Navigation (target)** | Vocabulary tab, Study log; Dictation tab **introduced in v2** (or stubbed in v1 if needed) | Add Dictation tab, deepen Study log; optional **Grammar** tab or area for grammar topics |

---

# Part A — Version 1 (current MVP): Vocabulary-first

### A.1 Purpose

motifly v1 helps French learners **learn and review words** through structured **word cards** (by part of speech), **translations** (e.g. English and Chinese glosses), **example sentences** for context, and a **simple study log** so practice stays lightweight and repeatable.

### A.2 Goals

- Browse and open **word cards** organized by type (e.g. noun, verb, adjective) and optional themes/tags.
- Show **headword**, **POS**, **glosses**, and **example** content appropriate to each card type (e.g. gender/articles/plural for nouns; core forms for verbs; agreement grid for adjectives — scope to what v1 ships).
- Support **audio** where available (headword and/or example) for listening reinforcement without requiring full dictation grading.
- Track **basic engagement or progress** per word/card (see Study log) without complex algorithms.

### A.3 Target users

- Beginner to intermediate French learners who want **vocabulary depth** (forms, context) before or alongside sentence drilling.
- Users who prefer **short sessions** and clear, calm UI.

### A.4 Version 1 scope

**In scope**

- **Vocabulary** list / library: browse, search, filter (e.g. by word type, frequency rank, thematic tag from seed data).
- **Word card** UI: shared shell (headword, audio, translations, example, POS) + **type-specific blocks** (noun / verb / adjective) per product design.
- **Study log** (lightweight): e.g. items viewed, simple marks, or minimal scores — enough to support “recent” and “needs attention” without full spaced repetition (SRS).
- **Local persistence** (SwiftData); no account required for v1.
- Curated **seed content** (e.g. frequency-list derived CSVs) as the initial word set.

**Out of scope for v1**

- **Sentence dictation** (listen → type → grade full sentence) — **Version 2**.
- **Grammar topic screens** as a first-class tab — **later** (may overlap v2); v1 may only show POS/theme on cards.
- Advanced **SRS** (intervals, scheduling algorithms) — optional evolution of Study log after v1; see Part C.
- AI correction, social, multiplayer, cloud sync, multiple languages.

### A.5 Core principles (v1)

- One **word card** in focus; avoid clutter.
- **Seed-driven** content quality: lemma, POS, examples, and glosses must be trustworthy enough for study.
- Leave room for **v2** dictation without rewriting v1 word models (examples can become dictation targets later).

### A.6 User problems (v1)

- Hard to **memorize gender, plurals, and forms** from flat word lists.
- Need **context** (example) next to the headword.
- Want **progress** without a heavy course or grammar product yet.

### A.7 Key user stories (v1)

- As a learner, I want to **open a word card** and see meaning, POS, and an example so I understand usage.
- As a learner, I want **noun/verb/adjective-specific** details when relevant so I learn patterns (not just a gloss).
- As a learner, I want to **find words** by type or theme quickly.
- As a learner, I want a **study log** so I can return to words I care about.

### A.8 V1 features (summary)

| Area | Description |
|------|-------------|
| **Vocabulary library** | List/detail of words from seed; filters; optional favorites. |
| **Word card** | Headword, POS badge, EN/ZH glosses, example FR (+ EN), type-specific module (as designed). |
| **Audio** | Play headword/example audio when assets or TTS exist; optional in v1. |
| **Study log** | Simple history / bookmarks / weak list; **not** full SRS in v1. |

### A.9 V1 primary screens (suggested)

- **Vocabulary** — library + word card detail.
- **Study log** — recent activity, saved/weak items (exact metrics TBD; keep simple).

*(A **Dictation** tab is a Version 2 addition; v1 may omit it or show a short “Coming in v2” placeholder if useful.)*

### A.10 V1 data model (SwiftData — indicative)

Names are illustrative; adjust in implementation.

- **WordEntry** (or **Lexeme**): id, frenchLemma, posTags, englishGloss, chineseGloss, exampleFrench, exampleEnglish, frequency metadata, thematic tag, wordType enum (noun | verb | adjective | other).
- **NounCardFields** (embedded or related): gender, articles, plural form, plural type — when applicable.
- **VerbCardFields** / **AdjectiveCardFields** — per card-type supplements.
- **StudyLogEntry** (light): word id, lastOpenedAt, optional simple flag or score.

Consolidate or split models for maintainability; avoid duplicating full sentence dictation fields until v2.

### A.11 V1 success metrics (examples)

- User opens a word card and reads example within **2 minutes** of launch.
- User can **find a word** by type/theme without confusion (target: **≥80%** success in usability tests).
- Users return to **Study log** or saved words multiple times per week (directional).

---

# Part B — Version 2 (planned): Sentence dictation + grammar

Version 2 adds **sentence-level dictation** (the core loop described in earlier PRD drafts) and **grammar** affordances. It builds on v1 content: **example sentences** can become **dictation prompts**; **grammar topics** can link to sentences and practice.

### B.1 Purpose

Extend motifly so users **listen to a French sentence, type what they hear**, get **basic correctness feedback**, and **organize review** by grammar and difficulty. Optional **Grammar** tab or section surfaces topics and linked practice.

### B.2 Goals (v2)

- Sentence-based **dictation**: audio → typed answer → check against reference French.
- **Grammar tags / topics** on sentences; filter review and (later) browse by topic.
- **User-created sentences** (optional): add text, image, audio, tags — local-first.
- **Richer study log** tied to **sentence attempts**; foundation for **SRS-style** scheduling in a later iteration (see Part C).

### B.3 Version 2 scope (high level)

**In scope (representative)**

- Sentence dictation practice flow (one sentence per screen).
- Audio playback; text input; submit; show correct vs user answer (exact match for MVP of dictation).
- Grammar tag(s) per sentence; filter library/review by tag.
- Retrieval or mastery **score per sentence** (simple formula acceptable).
- Sentence progress: attempts, correct count, last attempted, weak-first sorting.
- Optional image per sentence for memory.

**Still out of scope for v2 unless explicitly pulled in**

- Deep AI feedback, pronunciation scoring, cloud sync (can remain deferred).

### B.4 Sentence dictation features (detail)

#### B.4.1 Practice

- One sentence per screen; play audio; type answer; submit; reveal correct line after submit.

#### B.4.2 Media

- Optional image on sentence card; audio from URL or bundled file; replay allowed.

#### B.4.3 User-created content

- Add sentence, optional image, optional recording, optional grammar tags; SwiftData/local.

#### B.4.4 Answer checking

- Start with **exact match** (or documented normalization); show correct / incorrect.

#### B.4.5 Grammar tags

- Manual labels (e.g. passé composé, negation); filter lists by tag.

#### B.4.6 Retrieval score (sentence-level)

- Simple rule (e.g. +1 / -1 on correctness, floor at 0); sort weak sentences first.

#### B.4.7 Progress and logs (sentence-level)

- Last attempted, total attempts, correct count, retrieval score; detail screen per sentence.

### B.5 V2 primary screens (additions)

- **Dictation** — start practice, practice screen, result screen.
- **Sentence library** — sentences available for dictation (curated + user-created).
- **Grammar** (optional tab or hub) — topics and links into practice (align with [database_schema.md](database_schema.md) `grammar_topics` when using server-side schema).

### B.6 V2 data model extensions (indicative)

Extends v1 toward [database_schema.md](database_schema.md):

- **Sentence**: frenchText (reference for scoring), englishText, chineseText, difficulty, audio/image keys, source (system vs user).
- **GrammarTopic** + sentence–topic relations.
- **AttemptLog** per sentence: user input, scores, timestamps.
- **SentenceProgress** aggregates.

Word-level v1 models can **reference** the same example sentence when promoting a line to a dictation `Sentence` entity.

### B.7 V2 core flows

**Dictation practice**

1. User starts dictation.  
2. App shows one sentence card.  
3. User plays audio, types, submits.  
4. App shows correctness and updates sentence progress.

**Review weak sentences**

1. User opens review list sorted by low score.  
2. User practices weak items first.

---

# Part C — Future (post–v2 directions)

Not committed scope; informs architecture.

- **Grammar tab (full)**: dedicated browse/learn experience for grammar topics and example sentences (beyond tags only).
- **Spaced repetition (SRS)**: evolve **Study log** with scheduling (intervals, next review, notifications), likely using **attempt history** as input.
- Partial error highlighting, AI explanations, cloud sync, streaks, pronunciation — as separate initiatives.

---

# Shared requirements

### Non-functional

- Simple, responsive UI; few taps to core actions.
- Local-first persistence (SwiftData v1; optional backend later).
- Calm, distraction-free interface.
- No forced account in early versions.

### Risks

- **Scope creep** between v1 (words) and v2 (sentences): keep v1 shippable without dictation.
- Audio costs/API complexity in v2.
- **SRS** complexity: defer algorithms until Study log has stable usage data.

---

# Document summary

| Phase | What motifly is |
|-------|------------------|
| **v1** | A **vocabulary-first** app: word cards, glosses, examples, light study log — optimized for words and forms. |
| **v2** | Adds **sentence dictation**, **grammar tagging**, **sentence progress**, and richer review — the sentence-centric experience. |
| **Later** | Grammar hub, **SRS**, analytics, sync — as needed. |

The v1 app should stay **narrow and calm**; v2 adds **listening + typing** at sentence level without discarding v1 word data.
