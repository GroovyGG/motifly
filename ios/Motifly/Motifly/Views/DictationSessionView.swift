import SwiftUI

struct DictationSessionView: View {
    let unitIndex: Int
    let words: [VocabularyEntry]

    @State private var wordCount: Int = 10
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var correct = 0
    @State private var wrong = 0
    @State private var sessionDone = false
    @State private var lastWasCorrect: Bool?

    private var activeWords: [VocabularyEntry] {
        let n = min(max(1, wordCount), words.count)
        return Array(words.prefix(n))
    }

    private var current: VocabularyEntry? {
        guard currentIndex < activeWords.count else { return nil }
        return activeWords[currentIndex]
    }

    var body: some View {
        VStack(spacing: 20) {
            if sessionDone {
                sessionSummary
            } else {
                controls
                promptCard
                inputArea
            }
        }
        .padding()
        .navigationTitle("Unit \(unitIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wordCount = min(10, max(1, words.count))
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words in this session: \(activeWords.count) / \(words.count) in unit")
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(value: $wordCount, in: 1...max(1, words.count)) {
                Text("Repeat count: \(min(wordCount, words.count))")
            }
            .disabled(activeWords.isEmpty)
        }
        .onChange(of: wordCount) {
            resetSession()
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let w = current {
                Text("Type the French headword for:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(w.english)
                    .font(.title2)
                    .fontWeight(.medium)
                Text("Progress: \(currentIndex + 1) / \(activeWords.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var inputArea: some View {
        VStack(spacing: 12) {
            TextField("French lemma", text: $userInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let ok = lastWasCorrect {
                Text(ok ? "Correct" : "Incorrect")
                    .font(.subheadline)
                    .foregroundStyle(ok ? .green : .red)
            }

            HStack {
                Button("Check & Next") {
                    submitStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(current == nil)
            }
        }
    }

    private var sessionSummary: some View {
        VStack(spacing: 16) {
            Text("Session complete")
                .font(.title2)
            Text("Correct: \(correct)   Wrong: \(wrong)")
                .font(.headline)
            Button("Again") {
                resetSession()
                sessionDone = false
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private func submitStep() {
        guard let w = current else { return }
        let ok = DictationNormalization.isMatch(userInput: userInput, expectedLemma: w.frenchLemma)
        lastWasCorrect = ok
        if ok { correct += 1 } else { wrong += 1 }

        if currentIndex + 1 >= activeWords.count {
            sessionDone = true
            lastWasCorrect = nil
            return
        }
        currentIndex += 1
        userInput = ""
        lastWasCorrect = nil
    }

    private func resetSession() {
        currentIndex = 0
        userInput = ""
        correct = 0
        wrong = 0
        lastWasCorrect = nil
        sessionDone = false
    }
}

#Preview {
    NavigationStack {
        DictationSessionView(
            unitIndex: 0,
            words: []
        )
    }
}
