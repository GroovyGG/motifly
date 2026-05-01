import Foundation
import SwiftData

/// Per-word aggregate. Powers fast ordering (e.g. error-first / weak-first) and
/// stores the V1 memory-model fields described in `french_dictation_memory_model.md`.
///
/// Weakness is **spelling-only**: five spelling subtypes. No separate accent/article/etc. buckets.
@Model
final class DictationWordStats {
    @Attribute(.unique) var seedNumber: Int

    var attemptCount: Int
    var correctCount: Int
    var wrongCount: Int
    var lastAttemptAt: Date?
    var lastWrongAt: Date?

    // MARK: - V1 memory model (mastery, skills, errors, scheduling)

    /// 0-100 simplified display score. Computed by WordMasteryUpdater.
    var overallMastery: Double?
    /// 0-100. Recent dictation accuracy (correctness over the last attempts).
    var dictationScore: Double?
    /// 0-100. How clean the spelling is (penalizes spelling errors specifically).
    var spellingScore: Double?
    /// 0-100. How well the user can write the word from audio without many replays.
    var listeningScore: Double?
    /// 0-100. Inferred from how often the user revealed the translation hint.
    var meaningScore: Double?
    /// 0-10. Higher means the word is harder for this user.
    var difficulty: Double?

    // Inline defaults are required for SwiftData lightweight migration.
    /// Incremented on any `spelling_*` attempt (aggregate for reporting).
    var spellingErrorCount: Int = 0
    var spellingExtraCount: Int = 0
    var spellingMissingCount: Int = 0
    var spellingVowelCount: Int = 0
    var spellingConsonantCount: Int = 0
    var spellingMixedCount: Int = 0

    /// How many times the learner revealed the hint before submitting on this word.
    var usedHintCount: Int = 0
    /// Sum of replay counts over the recent window; helper for listeningScore math.
    var replaySumLast10: Int = 0

    /// Largest spelling subtype raw value, e.g. `spelling_vowel`. Nil when mastery is high
    /// or no spelling-subtype errors yet.
    var mainWeakness: String?

    /// Suggested date for the next review of this word (V1 simplified schedule).
    var nextReviewDate: Date?
    /// Last time the mastery state was recomputed (i.e. last submission).
    var lastReviewedAt: Date?
    /// Days between lastReviewedAt and nextReviewDate, used to grow intervals.
    var lastIntervalDays: Double?

    init(
        seedNumber: Int,
        attemptCount: Int = 0,
        correctCount: Int = 0,
        wrongCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastWrongAt: Date? = nil,
        overallMastery: Double? = nil,
        dictationScore: Double? = nil,
        spellingScore: Double? = nil,
        listeningScore: Double? = nil,
        meaningScore: Double? = nil,
        difficulty: Double? = nil,
        spellingErrorCount: Int = 0,
        spellingExtraCount: Int = 0,
        spellingMissingCount: Int = 0,
        spellingVowelCount: Int = 0,
        spellingConsonantCount: Int = 0,
        spellingMixedCount: Int = 0,
        usedHintCount: Int = 0,
        replaySumLast10: Int = 0,
        mainWeakness: String? = nil,
        nextReviewDate: Date? = nil,
        lastReviewedAt: Date? = nil,
        lastIntervalDays: Double? = nil
    ) {
        self.seedNumber = seedNumber
        self.attemptCount = attemptCount
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.lastAttemptAt = lastAttemptAt
        self.lastWrongAt = lastWrongAt
        self.overallMastery = overallMastery
        self.dictationScore = dictationScore
        self.spellingScore = spellingScore
        self.listeningScore = listeningScore
        self.meaningScore = meaningScore
        self.difficulty = difficulty
        self.spellingErrorCount = spellingErrorCount
        self.spellingExtraCount = spellingExtraCount
        self.spellingMissingCount = spellingMissingCount
        self.spellingVowelCount = spellingVowelCount
        self.spellingConsonantCount = spellingConsonantCount
        self.spellingMixedCount = spellingMixedCount
        self.usedHintCount = usedHintCount
        self.replaySumLast10 = replaySumLast10
        self.mainWeakness = mainWeakness
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
        self.lastIntervalDays = lastIntervalDays
    }
}
