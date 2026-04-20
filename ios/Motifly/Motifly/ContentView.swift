import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    /// True until first CSV import attempt finishes (do not cover the tab bar with a full-screen layer).
    @State private var vocabularyImportInProgress = CSVImportService.needsImport

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeView(isImportingVocabulary: vocabularyImportInProgress)
                }
            }
            Tab("Vocabulary", systemImage: "book") {
                NavigationStack {
                    VocabularyView()
                }
            }
            Tab("Dictation", systemImage: "mic") {
                NavigationStack {
                    DictationView()
                }
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            defer { vocabularyImportInProgress = false }
            guard CSVImportService.needsImport else { return }
            await CSVImportService.importIfNeededAsync(modelContext: modelContext)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        configurations: config
    )
    return ContentView()
        .modelContainer(container)
        .environmentObject(DictationProgressStore())
}
