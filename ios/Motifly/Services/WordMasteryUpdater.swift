import Foundation
import SwiftData

/// V1 mastery computation. Mutates `DictationWordStats` in place after each attempt.
///
/// Design notes (see `french_dictation_memory_model.md` §3, §6, §10):
/// - Skill scores are sliding-window aggregates over the most recent attempts so they
///   react to practice without needing a long history.
/// - Skills the app does not yet measure (recognition, pronunciation, production) are
///   substituted with a neutral 70 in the weighted blend so they neither boost nor
///   tank the displayed mastery before those modes ship.
/// - Scheduling is intentionally simple in V1; FSRS-style retrievability/stability
///   belong to V2.
enum WordMasteryUpdater {
    /// Number of recent attempts considered for skill score aggregates.
    static let recentWindow: Int = 10

    /// Threshold above which `mainWeakness` is suppressed in the UI.
    static let strongMasteryThreshold: Double = 90

    /// Apply a freshly inserted `attempt` to `stats`. `recentLogs` should include the new
    /// attempt and be sorted by `submittedAt` ascending; the function reads only the last
    /// `recentWindow` entries.
    ///
    /// Caller is responsible for `modelContext.save()` after this returns.
    static func applyAttempt(
        stats: DictationWordStats,
        attempt: DictationAttemptLog,
        errorKind: DictationErrorKind,
        recentLogs: [DictationAttemptLog],
        now: Date = .now
    ) {
        bumpErrorBucket(stats: stats, errorKind: errorKind)
        if attempt.usedHint == true {
            stats.usedHintCount += 1
        }

        let window = Array(recentLogs.suffix(recentWindow))
        let windowCount = max(1, window.count)
        let correctCount = window.filter { $0.isCorrect }.count
        let replaySum = window.reduce(0) { $0 + $1.replayCount }
        let hintCount = window.reduce(0) { $0 + (($1.usedHint == true) ? 1 : 0) }
        let spellingMistakes = window.filter { log in
            DictationErrorKind.countsTowardSpellingScorePenalty(log.errorType)
        }.count

        let dictationScore = clamp01_100(Double(correctCount) / Double(windowCount) * 100)

        let spellingPenalty = Double(spellingMistakes) / Double(windowCount) * 100
        let spellingScore = clamp01_100(100 - spellingPenalty)

        let avgReplay = Double(replaySum) / Double(windowCount)
        let listeningScore = clamp01_100(100 - min(avgReplay, 4) * 20)

        let hintRate = Double(hintCount) / Double(windowCount)
        let meaningScore = clamp01_100(100 - hintRate * 100)

        let lifetimeAttempts = max(1, stats.attemptCount)
        let lifetimeAccuracy = Double(stats.correctCount) / Double(lifetimeAttempts)
        let difficulty = max(0, min(10, 10 * (1 - lifetimeAccuracy)))

        let neutral: Double = 70
        let meaningBlend = (meaningScore + neutral) / 2
        let overallMastery = clamp01_100(
            0.20 * neutral
          + 0.25 * listeningScore
          + 0.25 * dictationScore
          + 0.15 * spellingScore
          + 0.10 * meaningBlend
          + 0.05 * neutral
        )

        stats.dictationScore = dictationScore
        stats.spellingScore = spellingScore
        stats.listeningScore = listeningScore
        stats.meaningScore = meaningScore
        stats.difficulty = difficulty
        stats.overallMastery = overallMastery
        stats.replaySumLast10 = replaySum

        stats.mainWeakness = computeMainWeakness(stats: stats, mastery: overallMastery)

        let scheduling = nextReview(
            isCorrect: attempt.isCorrect,
            usedHint: attempt.usedHint == true,
            elapsedMs: attempt.elapsedMs,
            previousIntervalDays: stats.lastIntervalDays,
            now: now
        )
        stats.nextReviewDate = scheduling.next
        stats.lastIntervalDays = scheduling.intervalDays
        stats.lastReviewedAt = now
    }

    // MARK: - Internals

    private static func bumpErrorBucket(stats: DictationWordStats, errorKind: DictationErrorKind) {
        switch errorKind {
        case .none:
            return
        case .spelling_extra:
            stats.spellingExtraCount += 1
            stats.spellingErrorCount += 1
        case .spelling_missing:
            stats.spellingMissingCount += 1
            stats.spellingErrorCount += 1
        case .spelling_vowel:
            stats.spellingVowelCount += 1
            stats.spellingErrorCount += 1
        case .spelling_consonant:
            stats.spellingConsonantCount += 1
            stats.spellingErrorCount += 1
        case .spelling_mixed:
            stats.spellingMixedCount += 1
            stats.spellingErrorCount += 1
        case .listening, .other:
            // Still recorded on `DictationAttemptLog`; weakness stays spelling-only.
            return
        }
    }

    private static func computeMainWeakness(stats: DictationWordStats, mastery: Double) -> String? {
        if mastery >= strongMasteryThreshold {
            return nil
        }
        let buckets: [(String, Int)] = [
            (DictationErrorKind.spelling_extra.rawValue, stats.spellingExtraCount),
            (DictationErrorKind.spelling_missing.rawValue, stats.spellingMissingCount),
            (DictationErrorKind.spelling_vowel.rawValue, stats.spellingVowelCount),
            (DictationErrorKind.spelling_consonant.rawValue, stats.spellingConsonantCount),
            (DictationErrorKind.spelling_mixed.rawValue, stats.spellingMixedCount)
        ]
        guard let top = buckets.max(by: { $0.1 < $1.1 }), top.1 > 0 else {
            return nil
        }
        return top.0
    }

    private static func nextReview(
        isCorrect: Bool,
        usedHint: Bool,
        elapsedMs: Int,
        previousIntervalDays: Double?,
        now: Date
    ) -> (next: Date, intervalDays: Double) {
        let interval: Double
        if !isCorrect {
            interval = 1
        } else if usedHint || elapsedMs > 8_000 {
            interval = 2
        } else {
            let prior = previousIntervalDays ?? 1
            interval = max(2, prior * 1.7)
        }
        let cappedInterval = min(interval, 30)
        let next = now.addingTimeInterval(cappedInterval * 86_400)
        return (next, cappedInterval)
    }

    private static func clamp01_100(_ x: Double) -> Double {
        max(0, min(100, x))
    }
}
