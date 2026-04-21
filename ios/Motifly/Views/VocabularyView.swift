import SwiftData
import SwiftUI

struct VocabularyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyEntry.seedNumber) private var entries: [VocabularyEntry]
    @Query(sort: \SearchHistoryEntry.searchedAt, order: .reverse) private var history: [SearchHistoryEntry]

    @State private var searchText = ""

    private var filtered: [VocabularyEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return entries.filter {
            $0.frenchLemma.localizedCaseInsensitiveContains(q)
                || $0.english.localizedCaseInsensitiveContains(q)
                || ($0.chineseExplanation ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private var recentFifty: [VocabularyEntry] {
        let map = Dictionary(uniqueKeysWithValues: entries.map { ($0.seedNumber, $0) })
        return history.prefix(50).compactMap { map[$0.seedNumber] }
    }

    var body: some View {
        List {
            if !searchText.isEmpty {
                Section("Results") {
                    ForEach(filtered, id: \.seedNumber) { e in
                        NavigationLink {
                            wordCard(for: e)
                        } label: {
                            row(e)
                        }
                    }
                }
            }

            Section("Recent searches (up to 50)") {
                if recentFifty.isEmpty {
                    Text("Search a word above — recent lookups appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentFifty, id: \.seedNumber) { e in
                        NavigationLink {
                            wordCard(for: e)
                        } label: {
                            row(e)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "French lemma or English gloss")
        .navigationTitle("Vocabulary")
    }

    @ViewBuilder
    private func wordCard(for e: VocabularyEntry) -> some View {
        switch e.entryKind {
        case "verb":
            VerbWordCardView(entry: e)
        case "adjective":
            AdjectiveWordCardView(entry: e)
        case "adverb":
            AdverbWordCardView(entry: e)
        default:
            NounWordCardView(entry: e)
        }
    }

    private func row(_ e: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(e.frenchLemma)
                .font(.headline)
            Text(e.english)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(rowKindLine(e))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func rowKindLine(_ e: VocabularyEntry) -> String {
        switch e.entryKind {
        case "verb":
            return "Verb · \(e.pos)"
        case "adjective":
            return "Adjective · \(e.pos)"
        case "adverb":
            return "Adverb · \(e.pos)"
        default:
            return e.pos
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: VocabularyEntry.self, SearchHistoryEntry.self,
        configurations: config
    )
    return NavigationStack { VocabularyView() }
        .modelContainer(container)
}
