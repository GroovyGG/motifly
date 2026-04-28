import Foundation
import SwiftData

/// One dictation run with session-level settings and summary counts.
@Model
final class DictationSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?

    /// e.g. "unit_3"
    var sourceScope: String
    /// random | az | za | errorFirst
    var orderMode: String
    /// JSON configuration for auto-play timing/source sequence.
    var timingProfileJSON: String

    var plannedCount: Int
    var attemptedCount: Int
    var correctCount: Int
    var wrongCount: Int

    /// running | completed | abandoned
    var status: String

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        sourceScope: String,
        orderMode: String,
        timingProfileJSON: String = "{}",
        plannedCount: Int,
        attemptedCount: Int = 0,
        correctCount: Int = 0,
        wrongCount: Int = 0,
        status: String = "running"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sourceScope = sourceScope
        self.orderMode = orderMode
        self.timingProfileJSON = timingProfileJSON
        self.plannedCount = plannedCount
        self.attemptedCount = attemptedCount
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.status = status
    }
}
