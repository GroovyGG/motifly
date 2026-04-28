import Foundation
import SwiftData

/// Append-only study timeline event across vocabulary and dictation actions.
@Model
final class VocabularyStudyEvent {
    @Attribute(.unique) var id: UUID
    /// 0 means session-level or non-word-specific event.
    var seedNumber: Int
    var eventType: String
    var occurredAt: Date
    /// Optional serialized context payload (JSON object).
    var contextJSON: String?

    init(
        id: UUID = UUID(),
        seedNumber: Int,
        eventType: String,
        occurredAt: Date = .now,
        contextJSON: String? = nil
    ) {
        self.id = id
        self.seedNumber = seedNumber
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.contextJSON = contextJSON
    }
}
