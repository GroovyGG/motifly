import SwiftData
import SwiftUI

struct DebugStudyTimelineView: View {
    @Query(sort: \VocabularyStudyEvent.occurredAt, order: .reverse) private var events: [VocabularyStudyEvent]

    var body: some View {
        List {
            if events.isEmpty {
                ContentUnavailableView(
                    "No events yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Trigger vocabulary or dictation actions to populate the study timeline.")
                )
            } else {
                ForEach(events, id: \.id) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.eventType)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(event.occurredAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if event.seedNumber > 0 {
                            Text("seed: \(event.seedNumber)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let context = event.contextJSON, !context.isEmpty {
                            Text(context)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                        }
                        Text(event.occurredAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Study Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyStudyEvent.self,
        configurations: config
    )
    let ctx = container.mainContext
    ctx.insert(VocabularyStudyEvent(seedNumber: 123, eventType: StudyEventType.cardView, contextJSON: "{\"source\":\"preview\"}"))
    return NavigationStack {
        DebugStudyTimelineView()
    }
    .modelContainer(container)
}
