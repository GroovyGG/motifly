import Foundation

/// Stored on `DictationAttemptLog.errorType` (raw string).
///
/// **Weakness is spelling-only** (five subtypes). `listening` / `other` are kept on the log
/// for analytics but do not increment spelling subtype counters on `DictationWordStats`.
enum DictationErrorKind: String {
    case none
    case spelling_extra
    case spelling_missing
    case spelling_vowel
    case spelling_consonant
    case spelling_mixed
    case listening
    case other

    /// Legacy logs: generic `spelling`, or old `accent` / `article` before spelling-only weakness.
    static func isSpellingFamily(_ raw: String?) -> Bool {
        guard let r = raw else { return false }
        if r == "spelling" { return true }
        if r == "accent" || r == "article" { return true }
        return r.hasPrefix("spelling_")
    }

    /// Used when penalizing spelling score from attempt history (includes legacy types).
    static func countsTowardSpellingScorePenalty(_ raw: String?) -> Bool {
        isSpellingFamily(raw)
    }

    static func weaknessDisplayName(forStored raw: String?) -> String {
        guard let raw else { return "—" }
        if let kind = DictationErrorKind(rawValue: raw) {
            switch kind {
            case .none: return "—"
            case .spelling_extra: return "Extra letter"
            case .spelling_missing: return "Missing letter"
            case .spelling_vowel: return "Vowel spelling"
            case .spelling_consonant: return "Consonant spelling"
            case .spelling_mixed: return "Mixed spelling"
            case .listening: return "Listening"
            case .other: return "Other"
            }
        }
        if raw == "spelling" { return "Spelling" }
        if raw == "accent" { return "Accent" }
        if raw == "article" { return "Article" }
        return raw.capitalized
    }
}

enum DictationErrorClassifier {
    private static let listeningReplayThreshold: Int = 3
    private static let spellingBandMaxDistance: Int = 4

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
        if strippedInput == strippedExpected, normInput != normExpected {
            return classifyDiacriticOnly(normUser: normInput, normExpected: normExpected)
        }

        let distance = levenshtein(normInput, normExpected)

        if replayCount >= listeningReplayThreshold && distance > spellingBandMaxDistance {
            return .listening
        }
        if distance > spellingBandMaxDistance {
            return .other
        }

        return classifySpellingBand(
            normUser: normInput,
            normExpected: normExpected,
            distance: distance
        )
    }

    // MARK: - Diacritic-only (formerly “accent”; now a spelling subtype)

    private static func classifyDiacriticOnly(normUser: String, normExpected: String) -> DictationErrorKind {
        let u = Array(normUser)
        let e = Array(normExpected)
        guard u.count == e.count else { return .spelling_mixed }
        for i in 0..<u.count where u[i] != e[i] {
            let au = stripDiacritics(String(u[i])).lowercased()
            if isVowelLetter(au) { return .spelling_vowel }
        }
        return .spelling_consonant
    }

    // MARK: - Spelling band

    private static func classifySpellingBand(
        normUser: String,
        normExpected: String,
        distance: Int
    ) -> DictationErrorKind {
        let u = Array(normUser)
        let e = Array(normExpected)
        let nu = u.count
        let ne = e.count
        let delta = nu - ne

        if distance == 1 {
            if delta == 1 { return .spelling_extra }
            if delta == -1 { return .spelling_missing }
            if nu == ne, let kind = singleSubstitutionVowelConsonant(u, e) {
                return kind
            }
            return .spelling_mixed
        }

        if distance == 2 {
            if nu == ne {
                if isAdjacentTransposition(u, e) { return .spelling_mixed }
                return doubleSubstitutionKind(u, e)
            }
            if delta == 2 { return .spelling_extra }
            if delta == -2 { return .spelling_missing }
            return .spelling_mixed
        }

        return .spelling_mixed
    }

    private static func singleSubstitutionVowelConsonant(_ u: [Character], _ e: [Character]) -> DictationErrorKind? {
        guard u.count == e.count else { return nil }
        var diffIdx: [Int] = []
        for i in 0..<u.count where u[i] != e[i] {
            diffIdx.append(i)
        }
        guard diffIdx.count == 1, let i = diffIdx.first else { return nil }
        let a = stripDiacritics(String(u[i])).lowercased()
        let b = stripDiacritics(String(e[i])).lowercased()
        let va = isVowelLetter(a)
        let vb = isVowelLetter(b)
        return (va || vb) ? .spelling_vowel : .spelling_consonant
    }

    private static func doubleSubstitutionKind(_ u: [Character], _ e: [Character]) -> DictationErrorKind {
        var idx: [Int] = []
        for i in 0..<u.count where u[i] != e[i] {
            idx.append(i)
        }
        guard idx.count == 2 else { return .spelling_mixed }
        for i in idx {
            let a = stripDiacritics(String(u[i])).lowercased()
            let b = stripDiacritics(String(e[i])).lowercased()
            if isVowelLetter(a) || isVowelLetter(b) {
                return .spelling_vowel
            }
        }
        return .spelling_consonant
    }

    private static func isAdjacentTransposition(_ u: [Character], _ e: [Character]) -> Bool {
        guard u.count == e.count, u.count >= 2 else { return false }
        for i in 0..<(u.count - 1) {
            if u[i] == e[i + 1], u[i + 1] == e[i] {
                let prefixMatch = (0..<i).allSatisfy { u[$0] == e[$0] }
                let suffixMatch = ((i + 2)..<u.count).allSatisfy { u[$0] == e[$0] }
                if prefixMatch, suffixMatch { return true }
            }
        }
        return false
    }

    private static func isVowelLetter(_ s: String) -> Bool {
        guard let c = s.first else { return false }
        let folded = String(c).lowercased()
        return "aeiouy".contains(folded)
    }

    private static func stripDiacritics(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
    }

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
