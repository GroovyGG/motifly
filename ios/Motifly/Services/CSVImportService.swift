import Foundation
import SwiftData

enum CSVImportService {
    private static let nounImportFlagKey = "motifly.csvImport.seedNouns.v2.done"
    private static let verbImportFlagKey = "motifly.csvImport.seedVerbs.v1.done"
    private static let adjectiveImportFlagKey = "motifly.csvImport.seedAdjectives.v1.done"
    private static let adverbImportFlagKey = "motifly.csvImport.seedAdverbs.v1.done"
    private static let legacyImportFlagKey = "motifly.csvImport.v1.done"

    private static let bundledNounsName = "seed_nouns"
    private static let bundledVerbsName = "seed_verbs"
    private static let bundledAdjectivesName = "seed_adjectives"
    private static let bundledAdverbsName = "seed_adv"

    /// Bundled CSVs live under `SeedData/` in the app target (copies of `data_seed/` at repo root).
    private static let bundledSeedsSubdirectory = "SeedData"

    /// Verbs use `number` from CSV + offset so they never collide with noun `seedNumber` (nouns use 1…~5k).
    nonisolated static let verbSeedNumberOffset = 10_000_000
    /// Adjectives use `number` from CSV + offset (distinct from nouns and verbs).
    nonisolated static let adjectiveSeedNumberOffset = 20_000_000
    /// Adverbs use `number` from CSV + offset (distinct from other kinds).
    nonisolated static let adverbSeedNumberOffset = 30_000_000

    static var needsImport: Bool {
        !UserDefaults.standard.bool(forKey: nounImportFlagKey)
            || !UserDefaults.standard.bool(forKey: verbImportFlagKey)
            || !UserDefaults.standard.bool(forKey: adjectiveImportFlagKey)
            || !UserDefaults.standard.bool(forKey: adverbImportFlagKey)
    }

    private static func markNounImportFinished() {
        UserDefaults.standard.set(true, forKey: nounImportFlagKey)
        UserDefaults.standard.removeObject(forKey: legacyImportFlagKey)
    }

    private static func markVerbImportFinished() {
        UserDefaults.standard.set(true, forKey: verbImportFlagKey)
    }

    private static func markAdjectiveImportFinished() {
        UserDefaults.standard.set(true, forKey: adjectiveImportFlagKey)
    }

    private static func markAdverbImportFinished() {
        UserDefaults.standard.set(true, forKey: adverbImportFlagKey)
    }

    /// Loads bundled noun / verb / adjective / adverb CSVs off the main actor, then inserts in batches.
    static func importIfNeededAsync(modelContext: ModelContext) async {
        let doNouns = !UserDefaults.standard.bool(forKey: nounImportFlagKey)
        let doVerbs = !UserDefaults.standard.bool(forKey: verbImportFlagKey)
        let doAdjectives = !UserDefaults.standard.bool(forKey: adjectiveImportFlagKey)
        let doAdverbs = !UserDefaults.standard.bool(forKey: adverbImportFlagKey)

        guard doNouns || doVerbs || doAdjectives || doAdverbs else { return }

        if doNouns {
            if let url = Bundle.main.url(
                forResource: bundledNounsName,
                withExtension: "csv",
                subdirectory: bundledSeedsSubdirectory
            ) {
                await MainActor.run {
                    deleteNounEntries(modelContext: modelContext)
                }

                let rows: [ParsedNounRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadNounRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 noun rows")
                } else {
                    await insertNounBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) nouns")
                }
                await MainActor.run { markNounImportFinished() }
            } else {
                print("CSVImportService: \(bundledNounsName).csv missing — skipping noun import")
                await MainActor.run { markNounImportFinished() }
            }
        }

        if doVerbs {
            if let url = Bundle.main.url(
                forResource: bundledVerbsName,
                withExtension: "csv",
                subdirectory: bundledSeedsSubdirectory
            ) {
                let rows: [ParsedVerbRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadVerbRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 verb rows")
                } else {
                    await MainActor.run {
                        deleteVerbEntries(modelContext: modelContext)
                    }
                    await insertVerbBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) verbs")
                }
                await MainActor.run { markVerbImportFinished() }
            } else {
                print("CSVImportService: \(bundledVerbsName).csv missing — skipping verb import")
                await MainActor.run { markVerbImportFinished() }
            }
        }

        if doAdjectives {
            if let url = Bundle.main.url(
                forResource: bundledAdjectivesName,
                withExtension: "csv",
                subdirectory: bundledSeedsSubdirectory
            ) {
                let rows: [ParsedAdjectiveRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadAdjectiveRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 adjective rows")
                } else {
                    await MainActor.run {
                        deleteAdjectiveEntries(modelContext: modelContext)
                    }
                    await insertAdjectiveBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) adjectives")
                }
                await MainActor.run { markAdjectiveImportFinished() }
            } else {
                print("CSVImportService: \(bundledAdjectivesName).csv missing — skipping adjective import")
                await MainActor.run { markAdjectiveImportFinished() }
            }
        }

        if doAdverbs {
            if let url = Bundle.main.url(
                forResource: bundledAdverbsName,
                withExtension: "csv",
                subdirectory: bundledSeedsSubdirectory
            ) {
                let rows: [ParsedAdverbRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadAdverbRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 adverb rows")
                } else {
                    await MainActor.run {
                        deleteAdverbEntries(modelContext: modelContext)
                    }
                    await insertAdverbBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) adverbs")
                }
                await MainActor.run { markAdverbImportFinished() }
            } else {
                print("CSVImportService: \(bundledAdverbsName).csv missing — skipping adverb import")
                await MainActor.run { markAdverbImportFinished() }
            }
        }
    }

    @MainActor
    private static func deleteNounEntries(modelContext: ModelContext) {
        let noun = "noun"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == nil || $0.entryKind == noun }
        )
        guard let nouns = try? modelContext.fetch(fd) else { return }
        for e in nouns {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteVerbEntries(modelContext: ModelContext) {
        let kind = "verb"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let verbs = try? modelContext.fetch(fd) else { return }
        for e in verbs {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteAdjectiveEntries(modelContext: ModelContext) {
        let kind = "adjective"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteAdverbEntries(modelContext: ModelContext) {
        let kind = "adverb"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    private static func insertNounBatches(rows: [ParsedNounRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "noun",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        genderCode: row.genderCode.trimmedOrNil,
                        lemmaArticle: row.lemmaArticle.trimmedOrNil,
                        pluralForm: row.pluralForm.trimmedOrNil,
                        pluralType: row.pluralType.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertVerbBatches(rows: [ParsedVerbRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "verb",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        verbGroup: row.verbGroup.trimmedOrNil,
                        verbAuxiliary: row.verbAuxiliary.trimmedOrNil,
                        verbPastParticiple: row.pastParticiple.trimmedOrNil,
                        verbPresentJSON: row.presentJSON,
                        verbPasseComposeJSON: row.passeComposeJSON
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertAdjectiveBatches(rows: [ParsedAdjectiveRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "adjective",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        adjMascSingular: row.mascSingular.trimmedOrNil,
                        adjFemSingular: row.femSingular.trimmedOrNil,
                        adjMascPlural: row.mascPlural.trimmedOrNil,
                        adjFemPlural: row.femPlural.trimmedOrNil,
                        adjAdjectiveType: row.adjectiveType.trimmedOrNil,
                        adjInvariable: row.invariable,
                        adjMemoryNote: row.memoryNote.trimmedOrNil,
                        adjExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertAdverbBatches(rows: [ParsedAdverbRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "adverb",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        advAdverbType: row.adverbType.trimmedOrNil,
                        advFormation: row.formation.trimmedOrNil,
                        advIsInvariable: row.invariable,
                        advPlacementPosition: row.placementPosition.trimmedOrNil,
                        advPlacementNote: row.placementNote.trimmedOrNil,
                        advPlacementExampleFront: row.placementExampleFront.trimmedOrNil,
                        advPlacementExampleEnd: row.placementExampleEnd.trimmedOrNil,
                        advMemoryNote: row.memoryNote.trimmedOrNil,
                        advExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    // MARK: - Noun parsing

    private struct ParsedNounRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let genderCode: String
        let lemmaArticle: String
        let pluralForm: String
        let pluralType: String
    }

    private nonisolated static func loadNounRows(from url: URL) -> [ParsedNounRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedNounRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            out.append(
                ParsedNounRow(
                    seedNumber: num,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_explanation"] ?? "",
                    genderCode: row["gender"] ?? "",
                    lemmaArticle: row["lemma_article"] ?? "",
                    pluralForm: row["plural_form"] ?? "",
                    pluralType: row["plural_type"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Verb parsing

    private struct ParsedVerbRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let verbGroup: String
        let verbAuxiliary: String
        let pastParticiple: String
        let presentJSON: String
        let passeComposeJSON: String
    }

    private nonisolated static func loadVerbRows(from url: URL) -> [ParsedVerbRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedVerbRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = verbSeedNumberOffset + num
            let presentJSON = conjugationJSON(row: row, persons: [
                ("je", "present_je"), ("tu", "present_tu"), ("il/elle", "present_il_elle"),
                ("nous", "present_nous"), ("vous", "present_vous"), ("ils/elles", "present_ils_elles"),
            ])
            let pcJSON = conjugationJSON(row: row, persons: [
                ("je", "pc_je"), ("tu", "pc_tu"), ("il/elle", "pc_il_elle"),
                ("nous", "pc_nous"), ("vous", "pc_vous"), ("ils/elles", "pc_ils_elles"),
            ])

            out.append(
                ParsedVerbRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_explanation"] ?? "",
                    verbGroup: row["verb_group"] ?? "",
                    verbAuxiliary: row["auxiliary"] ?? "",
                    pastParticiple: row["past_participle"] ?? "",
                    presentJSON: presentJSON,
                    passeComposeJSON: pcJSON
                )
            )
        }
        return out
    }

    // MARK: - Adjective parsing

    private struct ParsedAdjectiveRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let mascSingular: String
        let femSingular: String
        let mascPlural: String
        let femPlural: String
        let adjectiveType: String
        let invariable: Bool
        let memoryNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadAdjectiveRows(from url: URL) -> [ParsedAdjectiveRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedAdjectiveRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = adjectiveSeedNumberOffset + num
            let inv = (row["is_invariable"] ?? "").lowercased() == "true"

            out.append(
                ParsedAdjectiveRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    mascSingular: row["masc_singular"] ?? "",
                    femSingular: row["fem_singular"] ?? "",
                    mascPlural: row["masc_plural"] ?? "",
                    femPlural: row["fem_plural"] ?? "",
                    adjectiveType: row["adjective_type"] ?? "",
                    invariable: inv,
                    memoryNote: row["memory_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Adverb parsing

    private struct ParsedAdverbRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let adverbType: String
        let formation: String
        let invariable: Bool?
        let placementPosition: String
        let placementNote: String
        let placementExampleFront: String
        let placementExampleEnd: String
        let memoryNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadAdverbRows(from url: URL) -> [ParsedAdverbRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedAdverbRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = adverbSeedNumberOffset + num
            let invStr = (row["is_invariable"] ?? "").lowercased()
            let inv: Bool? = invStr == "true" ? true : (invStr == "false" ? false : nil)

            out.append(
                ParsedAdverbRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    adverbType: row["adverb_type"] ?? "",
                    formation: row["formation"] ?? "",
                    invariable: inv,
                    placementPosition: row["placement_position"] ?? "",
                    placementNote: row["placement_note"] ?? "",
                    placementExampleFront: row["placement_example_front"] ?? "",
                    placementExampleEnd: row["placement_example_end"] ?? "",
                    memoryNote: row["memory_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    private nonisolated static func conjugationJSON(
        row: [String: String],
        persons: [(String, String)]
    ) -> String {
        struct Pair: Codable {
            let person: String
            let form: String
        }
        var pairs: [Pair] = []
        for (label, key) in persons {
            let raw = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !raw.isEmpty {
                pairs.append(Pair(person: label, form: raw))
            }
        }
        guard let data = try? JSONEncoder().encode(pairs),
              let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }

    /// Splits one CSV line into fields (supports quoted commas).
    private nonisolated static func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }
}

private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
