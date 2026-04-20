import SwiftUI

/// v1.0: light shell; richer home content comes in later phases.
struct HomeView: View {
    var isImportingVocabulary: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                if isImportingVocabulary {
                    HStack(alignment: .center, spacing: 12) {
                        ProgressView()
                            .tint(.accentColor)
                            .controlSize(.regular)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Loading vocabulary")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("First launch imports the bundled dictionary. You can switch tabs while this runs.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Motifly")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Use Vocabulary to search the dictionary and Dictation to practice typing lemmas.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding()
        }
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack { HomeView() }
}
