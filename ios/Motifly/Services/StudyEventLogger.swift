import Foundation
import SwiftData

enum StudyEventType {
    static let cardView = "card_view"
    static let memoryNoteEdit = "memory_note_edit"
    static let mineSaved = "mine_saved"
    static let mineDiscarded = "mine_discarded"
    static let dictationSessionStart = "dictation_session_start"
    static let dictationSessionEnd = "dictation_session_end"
    static let dictationSubmit = "dictation_submit"
    static let dictationPromptPlay = "dictation_prompt_play"
    static let dictationReplay = "dictation_replay"
    static let reviewWordOpen = "review_word_open"
    static let reviewStartDictationTap = "review_start_dictation_tap"
    static let reviewTTSPlay = "review_tts_play"
    static let reviewMinePlay = "review_mine_play"
    static let dictationProgressCompleted = "dictation_progress_completed"
    static let dictationProgressAbandoned = "dictation_progress_abandoned"
}

enum StudyEventLogger {
    static func record(
        modelContext: ModelContext,
        seedNumber: Int,
        eventType: String,
        context: [String: String] = [:]
    ) {
        let contextJSON = context.isEmpty ? nil : encode(context: context)
        modelContext.insert(
            VocabularyStudyEvent(
                seedNumber: seedNumber,
                eventType: eventType,
                occurredAt: .now,
                contextJSON: contextJSON
            )
        )
        try? modelContext.save()
    }

    private static func encode(context: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: context, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }
}
