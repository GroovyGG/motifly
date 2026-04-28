import Foundation
import SwiftData

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
