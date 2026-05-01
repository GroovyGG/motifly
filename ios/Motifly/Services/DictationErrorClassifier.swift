import Foundation

/// One of the V1 error buckets from `french_dictation_memory_model.md` §6.
///
/// V1 keeps the rules deterministic and cheap; V2/V3 can replace this with
/// a smarter classifier (or model) without touching call sites.
enum DictationErrorKind: String {
    case none
    case accent
    case spelling
    case article
    case listening
    case grammar
    case other
}

enum DictationErrorClassifier {
    /// French articles/determiners we strip when checking for "wrong article" mistakes.
    /// Kept tiny on purpose; the broader determiner table lives in seed data.
    private static let articlePrefixes: [String] = [
        "le ", "la ", "les ", "l'",
        "un ", "une ", "des ",
        "du ", "de la ", "de l'", "de "
    ]

    /// Replays beyond this count, combined with a non-trivial diff, point to a listening problem.
    private static let listeningReplayThreshold: Int = 3

    /// Classify a single attempt.
    ///
    /// Inputs are expected to be the raw user input and lemma; we re-normalize internally so
    /// callers don't have to remember to do it.
    static func classify(
        userInput: String,
        expectedLemma: String,
        replayCount: Int,
        isCorrect: Bool
    ) -> DictationErrorKind {
        if isCorrect { return .none }

        let normInput = DictationNormalization.normalize(userInput).lowercased()
        let normExpected = DictationNormalization.normalize(expectedLemma).lowercased()

        if normInput.isEmpty { return .other }

        let strippedInput = stripDiacritics(normInput)
        let strippedExpected = stripDiacritics(normExpected)
        if strippedInput == strippedExpected {
            return .accent
        }

        let articleStrippedInput = stripLeadingArticle(normInput)
        let articleStrippedExpected = stripLeadingArticle(normExpected)
        if articleStrippedInput != normInput || articleStrippedExpected != normExpected {
            if articleStrippedInput == articleStrippedExpected {
                return .article
            }
        }

        let distance = levenshtein(normInput, normExpected)
        if distance <= 2 {
            return .spelling
        }

        if replayCount >= listeningReplayThreshold {
            return .listening
        }

        return .other
    }

    // MARK: - Helpers

    private static func stripDiacritics(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
    }

    private static func stripLeadingArticle(_ s: String) -> String {
        for prefix in articlePrefixes {
            if s.hasPrefix(prefix) {
                return String(s.dropFirst(prefix.count))
            }
        }
        return s
    }

    /// Classic iterative Levenshtein. Inputs are short lemmas, so allocation cost is irrelevant.
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    curr[j - 1] + 1,
                    prev[j] + 1,
                    prev[j - 1] + cost
                )
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }
}
