import SwiftUI
import SwiftData

@main
struct MotiflyApp: App {
    @StateObject private var dictationProgress = DictationProgressStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabularyEntry.self,
            SearchHistoryEntry.self,
        ])
        do {
            // Ensure Application Support exists before opening the SQLite store.
            // Avoids first-launch race where Core Data logs "parent directory missing"
            // then recovers (NSCocoaErrorDomain 512).
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeURL = appSupport.appendingPathComponent("default.store", isDirectory: false)
            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                ContentView()
            }
            .modelContainer(sharedModelContainer)
            .environment(\.modelContext, sharedModelContainer.mainContext)
            .environmentObject(dictationProgress)
        }
    }
}
