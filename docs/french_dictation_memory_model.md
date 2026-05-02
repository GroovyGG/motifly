# French Dictation App Memory Model

## Overview

This document defines the memory tracking model for a French dictation and vocabulary learning app.  
The goal of this model is to measure how well a learner has remembered, understood, heard, spelled, and used each French word.

Instead of using only one simple score, this model uses a combination of:

- A general memory state
- A skill-specific score matrix
- A dictation accuracy profile
- Error type tracking
- Confusion pair tracking
- Review history

This allows the app to answer not only:

> “Does the user know this word?”

but also:

> “Why is this word still weak?”

For example, a user may recognize a word visually but still fail to spell it correctly during dictation. This model is designed to capture that difference.

---

## Core Model Concept

The recommended model is:

```text
Word Mastery Model =
Memory State
+ Skill Matrix
+ Error Profile
+ Confusion Map
+ Review History
```

The app can show a simple mastery score in the UI, while internally storing more detailed learning data.

Example UI summary:

```text
Mastery: 76%
Status: Weak in spelling and dictation
Next Review: Tomorrow
Main Issue: Accent mistakes
```

---

## 1. Core Memory State

Each word should have a core memory state inspired by modern spaced repetition systems.

| Field | Meaning | Example |
|---|---|---:|
| `retrievability` | How likely the user can remember this word today | `0.82` |
| `stability` | How long the word can stay remembered | `12.5 days` |
| `difficulty` | How hard this word is for this user | `7.2 / 10` |
| `overallMastery` | A simplified display score for the UI | `76 / 100` |

### Retrievability Formula

A simple version of the memory decay formula can be:

```text
R(t) = e^(-t / S)
```

Where:

| Symbol | Meaning |
|---|---|
| `R(t)` | retrievability after `t` days |
| `t` | days since last review |
| `S` | stability of the word |

Meaning: the longer the time since the last review, the lower the recall probability becomes. A word with higher stability fades more slowly.

---

## 2. Skill Matrix

For a French dictation app, knowing a word is not one single ability.  
The user may know the meaning but still fail in listening, spelling, or pronunciation.

Therefore, each word should have a skill matrix.

| Skill Field | What It Measures | Example Score |
|---|---|---:|
| `recognitionScore` | Can the user understand the word when seeing it? | `95` |
| `listeningScore` | Can the user recognize the word from audio? | `78` |
| `dictationScore` | Can the user type the word correctly after hearing it? | `62` |
| `spellingScore` | Can the user spell the word correctly, including accents? | `55` |
| `meaningEnglishScore` | Can the user remember the English meaning? | `90` |
| `meaningChineseScore` | Can the user remember the Chinese meaning? | `92` |
| `pronunciationScore` | Can the user pronounce the word correctly? | `70` |
| `productionScore` | Can the user actively use the word in a sentence? | `45` |

---

## 3. Overall Mastery Score

The app can calculate a simplified overall mastery score from the skill matrix.

Because this app focuses on French dictation, listening, spelling, and dictation accuracy should have more weight.

Example formula:

```text
overallMastery =
  0.20 * recognitionScore
+ 0.25 * listeningScore
+ 0.25 * dictationScore
+ 0.15 * spellingScore
+ 0.10 * meaningScore
+ 0.05 * productionScore
```

Where:

```text
meaningScore = average(meaningEnglishScore, meaningChineseScore)
```

This gives more importance to dictation-related skills instead of treating every skill equally.

---

## 4. Dictation Attempt Model

Every time the user practices a word, the app should save a dictation attempt.

```swift
struct DictationAttempt {
    var wordId: UUID
    var userInput: String
    var correctAnswer: String
    var isExactCorrect: Bool
    var normalizedAccuracy: Double
    var accentAccuracy: Double
    var spellingAccuracy: Double
    var responseTimeSeconds: Double
    var usedHint: Bool
    var listenedTimes: Int
    var attemptDate: Date
}
```

### Why Save Attempt History?

Saving every attempt allows the app to:

- Track improvement over time
- Detect repeated mistakes
- Calculate review intervals
- Identify whether the user is improving in spelling, listening, or memory
- Show learning logs similar to a GitHub contribution heatmap

---

## 5. Dictation Scoring Rules

Each dictation attempt can be converted into a score.

| Case | Suggested Score |
|---|---:|
| Exact correct and fast | `100` |
| Correct but slow | `85` |
| Accent mistake only | `75` |
| Minor spelling mistake | `65` |
| Wrong article or gender | `55` |
| Recognized meaning but typed the wrong word | `45` |
| Completely wrong | `20` |
| Blank or skipped | `0` |

This is especially useful for French because many mistakes are not simple spelling errors. Some errors are grammar-based, accent-based, or listening-based.

Example French-specific mistakes:

```text
é / e
a / à
ou / où
ce / se
son / sont
du / de / des
leur / leurs
```

---

## 6. Error Profile

Each word should have an error profile to track what type of mistake happens repeatedly.

```swift
struct ErrorProfile {
    var accentErrorCount: Int
    var genderErrorCount: Int
    var spellingErrorCount: Int
    var articleErrorCount: Int
    var listeningErrorCount: Int
    var grammarErrorCount: Int
    var confusionErrorCount: Int
}
```

### Example

For the word `où`, the app may detect:

```text
accentErrorCount = 5
spellingErrorCount = 1
listeningErrorCount = 0
```

This means the user probably understands the word, but often forgets the accent.

The app can then show:

```text
Main Issue: Accent mistake
Suggested Review: Accent-focused review
```

---

## 7. Confusion Map

French learners often confuse words that sound similar or look similar.  
The app should track confusion pairs.

```swift
struct ConfusionPair {
    var wordId: UUID
    var confusedWithWordId: UUID
    var confusionCount: Int
    var lastConfusedAt: Date
}
```

Example confusion pairs:

| Correct Word | Common Mistake |
|---|---|
| `ce` | `se` |
| `son` | `sont` |
| `a` | `à` |
| `ou` | `où` |
| `du` | `de` |
| `leur` | `leurs` |

Instead of only marking the answer wrong, the app should record the confusion relationship.

This allows the app to later create focused practice such as:

```text
Review Set: ce vs se
Review Set: son vs sont
Review Set: a vs à
```

---

## 8. Review Result Categories

After each review, the app can classify the result into one of four categories.

| Result | Meaning | Effect |
|---|---|---|
| `again` | The user failed or could not remember | Lower retrievability, increase difficulty |
| `hard` | Correct but slow or with several small mistakes | Small stability increase |
| `good` | Correct with normal effort | Normal stability increase |
| `easy` | Fast and perfect | Large stability increase |

This makes it easier to calculate the next review date.

---

## 9. Suggested Data Model

### Word Memory State

```swift
struct WordMemoryState {
    var wordId: UUID
    var retrievability: Double
    var stability: Double
    var difficulty: Double
    var overallMastery: Double
    var nextReviewDate: Date
    var lastReviewedAt: Date?
}
```

### Skill Matrix

```swift
struct SkillMatrix {
    var wordId: UUID
    var recognitionScore: Double
    var listeningScore: Double
    var dictationScore: Double
    var spellingScore: Double
    var meaningEnglishScore: Double
    var meaningChineseScore: Double
    var pronunciationScore: Double
    var productionScore: Double
}
```

### Error Profile

```swift
struct WordErrorProfile {
    var wordId: UUID
    var accentErrorCount: Int
    var genderErrorCount: Int
    var spellingErrorCount: Int
    var articleErrorCount: Int
    var listeningErrorCount: Int
    var grammarErrorCount: Int
    var confusionErrorCount: Int
}
```

### Review Log

```swift
struct ReviewLog {
    var id: UUID
    var wordId: UUID
    var reviewDate: Date
    var result: ReviewResult
    var score: Double
    var responseTimeSeconds: Double
    var usedHint: Bool
    var listenedTimes: Int
}

enum ReviewResult {
    case again
    case hard
    case good
    case easy
}
```

---

## 10. V1 Implementation Recommendation

For the first version of the app, it is better to keep the model simple.

### V1 Fields

```text
overallMastery
dictationScore
spellingScore
listeningScore
difficulty
nextReviewDate
errorTypeCounts
```

### V1 Goal

The V1 model should answer:

```text
Is this word strong or weak?
What is the main weakness?
When should the user review it again?
```

Example:

```text
Word: aujourd’hui
Mastery: 68%
Main Weakness: spelling
Next Review: tomorrow
```

---

## 11. V2 Implementation Recommendation

In V2, the app can add a more complete memory model.

### V2 Additions

```text
retrievability
stability
difficulty
full skill matrix
confusion pairs
review history analysis
```

### V2 Goal

The V2 model should answer:

```text
How likely is the user to remember this word today?
How fast is this word becoming stable?
Which skill is blocking mastery?
Which words are commonly confused with this word?
```

---

## 12. V3 Implementation Recommendation

In V3, the app can add AI-assisted diagnosis.

### V3 Examples

```text
This word is weak because of accent errors.
This word is confused with another homophone.
This word is understood visually but not from audio.
This word should be reviewed with similar-sounding words.
This word is ready to move from recognition practice to production practice.
```

### V3 Goal

The V3 model should become a personalized French learning assistant, not only a spaced repetition tool.

---

## 13. Example Word State

```json
{
  "word": "aujourd’hui",
  "retrievability": 0.72,
  "stability": 6.5,
  "difficulty": 7.8,
  "overallMastery": 68,
  "skillMatrix": {
    "recognitionScore": 92,
    "listeningScore": 76,
    "dictationScore": 61,
    "spellingScore": 54,
    "meaningEnglishScore": 95,
    "meaningChineseScore": 96,
    "pronunciationScore": 70,
    "productionScore": 50
  },
  "mainWeakness": "spelling",
  "nextReviewDate": "2026-05-02"
}
```

---

## 14. Product Design Principle

The user interface should stay simple, but the internal model should be rich.

### UI Layer

Show:

```text
Mastery: 68%
Main Weakness: Spelling
Next Review: Tomorrow
```

### Data Layer

Store:

```text
Memory state
Skill matrix
Attempt history
Error profile
Confusion map
Review intervals
```

This keeps the app easy to use while still allowing advanced personalized learning logic.

---

## Final Recommendation

For this French dictation app, the best memory tracking model is:

```text
Simplified FSRS-style memory state
+ French-specific skill matrix
+ Dictation accuracy scoring
+ Error type tracking
+ Confusion pair tracking
```

This model is more powerful than a normal vocabulary flashcard score because it can identify the exact reason a word is weak.

A word can be weak because of:

- Poor listening recognition
- Accent mistakes
- Gender or article mistakes
- Spelling instability
- Confusion with a similar word
- Low active production ability

By tracking these separately, the app can create smarter reviews and give the learner more useful feedback.

