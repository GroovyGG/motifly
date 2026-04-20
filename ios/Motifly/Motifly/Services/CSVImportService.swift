import Foundation
import SwiftData

enum CSVImportService {
    /// Noun seed from `seed_nouns.csv` (replaces older `french_5000` bundle).
    private static let importFlagKey = "motifly.csvImport.seedNouns.v2.done"
    private static let legacyImportFlagKey = "motifly.csvImport.v1.done"

    private static let bundledCSVName = "seed_nouns"

    static var needsImport: Bool {
        !UserDefaults.standard.bool(forKey: importFlagKey)
    }

    private static func markImportFinished() {
        UserDefaults.standard.set(true, forKey: importFlagKey)
        UserDefaults.standard.removeObject(forKey: legacyImportFlagKey)
    }

    /// Loads and parses CSV off the main actor, then inserts in batches so the UI can render.
    static func importIfNeededAsync(modelContext: ModelContext) async {
        guard needsImport else { return }

        guard let url = Bundle.main.url(forResource: bundledCSVName, withExtension: "csv") else {
            print("CSVImportService: \(bundledCSVName).csv not in bundle — marking import finished to avoid a stuck launch")
            markImportFinished()
            return
        }

        await MainActor.run {
            deleteAllVocabularyEntries(modelContext: modelContext)
        }

        let rows: [ParsedCSVRow] = await Task.detached(priority: .userInitiated) {
            Self.loadRows(from: url)
        }.value

        guard !rows.isEmpty else {
            print("CSVImportService: parsed 0 rows — check CSV; marking import finished so the app can run")
            markImportFinished()
            return
        }

        let batchSize = 200
        var inserted = 0
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
                        chineseExplanation: row.chineseExplanation,
                        genderCode: row.genderCode,
                        lemmaArticle: row.lemmaArticle,
                        pluralForm: row.pluralForm,
                        pluralType: row.pluralType
                    )
                    modelContext.insert(entry)
                    inserted += 1
                }
                do {
                    try modelContext.save()
                } catch {
                    print("CSVImportService batch save error: \(error)")
                }
            }
            await Task.yield()
            index = end
        }

        await MainActor.run {
            do {
                try modelContext.save()
                markImportFinished()
                print("CSVImportService: imported \(inserted) rows from \(bundledCSVName).csv")
            } catch {
                print("CSVImportService final save error: \(error)")
            }
        }
    }

    @MainActor
    private static func deleteAllVocabularyEntries(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<VocabularyEntry>()
        guard let all = try? modelContext.fetch(descriptor) else { return }
        for entry in all {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private struct ParsedCSVRow {
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

    private nonisolated static func loadRows(from url: URL) -> [ParsedCSVRow] {
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

        var out: [ParsedCSVRow] = []
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
                ParsedCSVRow(
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
