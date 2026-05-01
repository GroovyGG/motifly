import Foundation

/// Dictation error bucket stored on `DictationAttemptLog.errorType` (raw string).
///
/// Spelling is split into purposeful subtypes for a vocabulary dictation app:
/// extra letter, missing letter, vowel-related substitution, consonant-only substitution,
/// and mixed / complex edits (transpositions, multiple edits, etc.).
enum DictationErrorKind: String {
    case none
    case accent
    /// User typed one or more extra letters vs the lemma (insertion-heavy).
    case spelling_extra
    /// User omitted one or more letters vs the lemma (deletion-heavy).
    case spelling_missing
    /// Substitution where a vowel (a,e,i,o,u,y, including accented forms) is involved.
    case spelling_vowel
    /// Single- or double-substitution errors involving only consonants.
    case spelling_consonant
    /// Transposition, multiple edit types, or Levenshtein > 2 within the spelling band.
    case spelling_mixed
    case article
    case listening
    case grammar
    case other

    /// Legacy logs may still carry `spelling` before the subtype split.
    static func isSpellingFamily(_ raw: String?) -> Bool {
        guard let r = raw else { return false }
        if r == "spelling" { return true }
        return r.hasPrefix("spelling_")
    }

    /// Short English label for weakness chips (not raw snake_case).
    static func weaknessDisplayName(forStored raw: String?) -> String {
        guard let raw, let kind = DictationErrorKind(rawValue: raw) else {
            if raw == "spelling" { return "Spelling" }
            return raw?.capitalized ?? "—"
        }
        switch kind {
        case .none: return "—"
        case .accent: return "Accent"
        case .spelling_extra: return "Extra letter"
        case .spelling_missing: return "Missing letter"
        case .spelling_vowel: return "Vowel spelling"
        case .spelling_consonant: return "Consonant spelling"
        case .spelling_mixed: return "Mixed spelling"
        case .article: return "Article"
        case .listening: return "Listening"
        case .grammar: return "Grammar"
        case .other: return "Other"
        }
    }
}

enum DictationErrorClassifier {
    /// French articles/determiners we strip when checking for "wrong article" mistakes.
    private static let articlePrefixes: [String] = [
        "le ", "la ", "les ", "l'",
        "un ", "une ", "des ",
        "du ", "de la ", "de l'", "de "
    ]

    private static let listeningReplayThreshold: Int = 3
    /// Beyond this Levenshtein distance we treat as listening / other unless replay is low.
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

    // MARK: - Spelling band (purposeful subtypes)

    /// `distance` is in `1...spellingBandMaxDistance`.
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

        // distance 3–4
        return .spelling_mixed
    }

    /// Same length, exactly one differing index.
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

    /// Same length, two mismatched positions (not a transposition).
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

    /// After stripping diacritics, `s` is one grapheme (lowercase).
    private static func isVowelLetter(_ s: String) -> Bool {
        guard let c = s.first else { return false }
        let folded = String(c).lowercased()
        return "aeiouy".contains(folded)
    }

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
