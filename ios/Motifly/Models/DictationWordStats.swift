import Foundation
import SwiftData

/// Incremental per-word aggregates to support fast ordering (e.g. error-first).
@Model
final class DictationWordStats {
    @Attribute(.unique) var seedNumber: Int

    var attemptCount: Int
    var correctCount: Int
    var wrongCount: Int
    var lastAttemptAt: Date?
    var lastWrongAt: Date?

    init(
        seedNumber: Int,
        attemptCount: Int = 0,
        correctCount: Int = 0,
        wrongCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastWrongAt: Date? = nil
    ) {
        self.seedNumber = seedNumber
        self.attemptCount = attemptCount
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.lastAttemptAt = lastAttemptAt
        self.lastWrongAt = lastWrongAt
    }
}
