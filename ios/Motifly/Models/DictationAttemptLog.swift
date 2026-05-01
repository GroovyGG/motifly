import Foundation
import SwiftData

/// One word attempt event in a dictation session.
@Model
final class DictationAttemptLog {
    @Attribute(.unique) var id: UUID

    /// FK-by-value to `DictationSession.id`
    var sessionId: UUID
    /// FK-by-value to `VocabularyEntry.seedNumber`
    var seedNumber: Int
    var promptIndex: Int

    var expectedLemma: String
    var userInput: String
    var normalizedExpected: String
    var normalizedInput: String
    var isCorrect: Bool

    var promptShownAt: Date
    var submittedAt: Date
    var elapsedMs: Int

    var replayCount: Int
    /// JSON array of playback passes (`tts`/`mine` etc.).
    var playTraceJSON: String
    /// none | accent | typo | other
    var errorType: String?
    /// True if the learner revealed the English/Chinese translation hint before submitting.
    /// Optional for SwiftData lightweight migration of stores written before this column existed.
    var usedHint: Bool?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        seedNumber: Int,
        promptIndex: Int,
        expectedLemma: String,
        userInput: String,
        normalizedExpected: String,
        normalizedInput: String,
        isCorrect: Bool,
        promptShownAt: Date,
        submittedAt: Date,
        elapsedMs: Int,
        replayCount: Int = 0,
        playTraceJSON: String = "[]",
        errorType: String? = nil,
        usedHint: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.seedNumber = seedNumber
        self.promptIndex = promptIndex
        self.expectedLemma = expectedLemma
        self.userInput = userInput
        self.normalizedExpected = normalizedExpected
        self.normalizedInput = normalizedInput
        self.isCorrect = isCorrect
        self.promptShownAt = promptShownAt
        self.submittedAt = submittedAt
        self.elapsedMs = elapsedMs
        self.replayCount = replayCount
        self.playTraceJSON = playTraceJSON
        self.errorType = errorType
        self.usedHint = usedHint
    }
}
