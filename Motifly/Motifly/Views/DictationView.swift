import SwiftData
import SwiftUI

struct DictationView: View {
    @Query(sort: \VocabularyEntry.seedNumber) private var entries: [VocabularyEntry]

    private var unitCount: Int {
        guard !entries.isEmpty else { return 0 }
        return (entries.count + 49) / 50
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No vocabulary",
                    systemImage: "tray",
                    description: Text("Import runs on first launch. Relaunch after install.")
                )
            } else {
                List(0..<unitCount, id: \.self) { unitIndex in
                    let range = unitRange(unitIndex: unitIndex)
                    NavigationLink {
                        DictationSessionView(
                            unitIndex: unitIndex,
                            words: Array(entries[range])
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit \(unitIndex + 1)")
                                .font(.headline)
                            Text("Words \(entries[range.lowerBound].seedNumber)–\(entries[range.upperBound - 1].seedNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Dictation")
    }

    private func unitRange(unitIndex: Int) -> Range<Int> {
        let start = unitIndex * 50
        let end = min(start + 50, entries.count)
        return start..<end
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        configurations: config
    )
    return NavigationStack { DictationView() }
        .modelContainer(container)
}
