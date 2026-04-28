import Foundation
import SwiftData

enum DictationOrderMode: String, CaseIterable, Identifiable {
    case random
    case alphabeticalAZ
    case alphabeticalZA
    case errorFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .random:
            return "Random"
        case .alphabeticalAZ:
            return "A–Z"
        case .alphabeticalZA:
            return "Z–A"
        case .errorFirst:
            return "Error first"
        }
    }
}

enum DictationWordOrdering {
    static func orderedWords(
        _ words: [VocabularyEntry],
        mode: DictationOrderMode,
        modelContext: ModelContext
    ) -> [VocabularyEntry] {
        switch mode {
        case .random:
            return words.shuffled()
        case .alphabeticalAZ:
            return words.sorted {
                $0.frenchLemma.localizedCaseInsensitiveCompare($1.frenchLemma) == .orderedAscending
            }
        case .alphabeticalZA:
            return words.sorted {
                $0.frenchLemma.localizedCaseInsensitiveCompare($1.frenchLemma) == .orderedDescending
            }
        case .errorFirst:
            return orderByErrorPriority(words: words, modelContext: modelContext)
        }
    }

    private static func orderByErrorPriority(
        words: [VocabularyEntry],
        modelContext: ModelContext
    ) -> [VocabularyEntry] {
        let fd = FetchDescriptor<DictationAttemptLog>()
        let logs = (try? modelContext.fetch(fd)) ?? []

        var attemptsBySeed: [Int: Int] = [:]
        var wrongBySeed: [Int: Int] = [:]
        var lastWrongAtBySeed: [Int: Date] = [:]

        for log in logs {
            attemptsBySeed[log.seedNumber, default: 0] += 1
            if !log.isCorrect {
                wrongBySeed[log.seedNumber, default: 0] += 1
                let prev = lastWrongAtBySeed[log.seedNumber]
                if prev == nil || prev! < log.submittedAt {
                    lastWrongAtBySeed[log.seedNumber] = log.submittedAt
                }
            }
        }

        return words.sorted { lhs, rhs in
            let lWrong = wrongBySeed[lhs.seedNumber, default: 0]
            let rWrong = wrongBySeed[rhs.seedNumber, default: 0]
            if lWrong != rWrong { return lWrong > rWrong }

            let lAttempts = attemptsBySeed[lhs.seedNumber, default: 0]
            let rAttempts = attemptsBySeed[rhs.seedNumber, default: 0]
            if lAttempts != rAttempts { return lAttempts > rAttempts }

            let lLastWrong = lastWrongAtBySeed[lhs.seedNumber]
            let rLastWrong = lastWrongAtBySeed[rhs.seedNumber]
            if lLastWrong != rLastWrong { return (lLastWrong ?? .distantPast) > (rLastWrong ?? .distantPast) }

            return lhs.frenchLemma.localizedCaseInsensitiveCompare(rhs.frenchLemma) == .orderedAscending
        }
    }
}
