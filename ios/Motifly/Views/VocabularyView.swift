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
        return entries.filter { entryMatchesSearch($0, query: q) }
    }

    /// Matches lemma, glosses, POS tags, entry kind, and common grammar terms (e.g. “pronoun” → `pro` in POS).
    private func entryMatchesSearch(_ e: VocabularyEntry, query: String) -> Bool {
        if e.frenchLemma.localizedCaseInsensitiveContains(query) { return true }
        if e.english.localizedCaseInsensitiveContains(query) { return true }
        if (e.chineseExplanation ?? "").localizedCaseInsensitiveContains(query) { return true }
        if e.pos.localizedCaseInsensitiveContains(query) { return true }
        if let k = e.entryKind, k.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.detDeterminerType, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.advAdverbType, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.adjAdjectiveType, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.proPronounType, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.proUsageNote, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.prepPrepositionType, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.prepUsageNote, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.prepCoreMeaning, t.localizedCaseInsensitiveContains(query) { return true }
        if let t = e.prepMemoryNote, t.localizedCaseInsensitiveContains(query) { return true }

        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let posLower = e.pos.lowercased()

        // “Pronoun” in seeds is usually tagged as `pro` in CSV `pos`, not the English word “pronoun”.
        if lower == "pronoun" || lower == "pronouns" || lower == "pronom" {
            if e.entryKind == "pronoun" { return true }
            if posLower.contains("pro") { return true }
        }

        // Help “determiner” find `det` tags when not using the dedicated determiner kind string in POS alone.
        if lower == "determiner" || lower == "determiners" {
            if e.entryKind == "determiner" { return true }
            if posLower.contains("det") { return true }
        }

        if lower == "preposition" || lower == "prepositions" || lower == "prep" || lower == "préposition"
            || lower == "prépositions" {
            if e.entryKind == "preposition" { return true }
            if posLower.contains("prep") { return true }
        }

        return false
    }

    private var recentFifty: [VocabularyEntry] {
        let map = Dictionary(uniqueKeysWithValues: entries.map { ($0.seedNumber, $0) })
        return history.prefix(50).compactMap { map[$0.seedNumber] }
    }

    var body: some View {
        List {
            if !searchText.isEmpty {
                Section("Results") {
                    if filtered.isEmpty {
                        Text("No matches. Try a French word, English gloss, POS tag (e.g. pro, det, prep), or words like pronoun / determiner / preposition.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered, id: \.seedNumber) { e in
                            NavigationLink {
                                wordCard(for: e)
                            } label: {
                                row(e)
                            }
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
        .searchable(text: $searchText, prompt: "Lemma, English, POS (pro, det), or kind")
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
        case "determiner":
            DeterminerWordCardView(entry: e)
        case "pronoun":
            PronounWordCardView(entry: e)
        case "preposition":
            PrepositionWordCardView(entry: e)
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
        case "determiner":
            return "Determiner · \(e.pos)"
        case "pronoun":
            return "Pronoun · \(e.pos)"
        case "preposition":
            return "Preposition · \(e.pos)"
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
