import Foundation

enum DictationNormalization {
    /// NFC trim + case-insensitive compare for lemma dictation.
    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }

    static func isMatch(userInput: String, expectedLemma: String) -> Bool {
        normalize(userInput).localizedCaseInsensitiveCompare(normalize(expectedLemma)) == .orderedSame
    }
}
