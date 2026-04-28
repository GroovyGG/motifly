import SwiftUI
import SwiftData

struct DictationSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictationProgress: DictationProgressStore

    let unitIndex: Int
    let words: [VocabularyEntry]

    @State private var wordCount: Int = 10
    @State private var orderMode: DictationOrderMode = .random
    @State private var orderedUnitWords: [VocabularyEntry] = []
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var correct = 0
    @State private var wrong = 0
    @State private var sessionDone = false
    @State private var lastWasCorrect: Bool?
    @State private var currentSessionId: UUID?
    @State private var promptShownAt: Date = .now

    private var activeWords: [VocabularyEntry] {
        let n = min(max(1, wordCount), orderedUnitWords.count)
        return Array(orderedUnitWords.prefix(n))
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
            refreshOrderedWords()
            wordCount = min(10, max(1, orderedUnitWords.count))
            resetSession()
            startNewSession()
        }
        .onChange(of: sessionDone) { _, done in
            if done {
                let total = correct + wrong
                dictationProgress.completeSession(unitIndex: unitIndex, correct: correct, total: total)
                finishCurrentSession(status: "completed")
            }
        }
        .onChange(of: currentIndex) { _, _ in
            promptShownAt = .now
        }
        .onChange(of: wordCount) { _, _ in
            if !sessionDone {
                finishCurrentSession(status: "abandoned")
            }
            resetSession()
            startNewSession()
        }
        .onChange(of: orderMode) { _, _ in
            if !sessionDone {
                finishCurrentSession(status: "abandoned")
            }
            refreshOrderedWords()
            wordCount = min(max(1, wordCount), max(1, orderedUnitWords.count))
            resetSession()
            startNewSession()
        }
        .onDisappear {
            if !sessionDone {
                dictationProgress.abandonSession(unitIndex: unitIndex)
                finishCurrentSession(status: "abandoned")
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words in this session: \(activeWords.count) / \(orderedUnitWords.count) in unit")
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(value: $wordCount, in: 1...max(1, orderedUnitWords.count)) {
                Text("Repeat count: \(min(wordCount, orderedUnitWords.count))")
            }
            .disabled(activeWords.isEmpty)

            Picker("Order mode", selection: $orderMode) {
                ForEach(DictationOrderMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
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
        recordAttempt(for: w, isCorrect: ok)
        updateRunningSessionSummary()

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
        promptShownAt = .now
    }

    private func refreshOrderedWords() {
        orderedUnitWords = DictationWordOrdering.orderedWords(
            words,
            mode: orderMode,
            modelContext: modelContext
        )
    }

    private func startNewSession() {
        guard !activeWords.isEmpty else { return }
        let session = DictationSession(
            sourceScope: "unit_\(unitIndex + 1)",
            orderMode: orderMode.rawValue,
            timingProfileJSON: "{}",
            plannedCount: activeWords.count
        )
        modelContext.insert(session)
        try? modelContext.save()
        currentSessionId = session.id
    }

    private func recordAttempt(for word: VocabularyEntry, isCorrect: Bool) {
        guard let sessionId = currentSessionId else { return }
        let now = Date()
        let elapsedMs = max(0, Int(now.timeIntervalSince(promptShownAt) * 1000.0))
        let normalizedExpected = DictationNormalization.normalize(word.frenchLemma)
        let normalizedInput = DictationNormalization.normalize(userInput)
        let attempt = DictationAttemptLog(
            sessionId: sessionId,
            seedNumber: word.seedNumber,
            promptIndex: currentIndex,
            expectedLemma: word.frenchLemma,
            userInput: userInput,
            normalizedExpected: normalizedExpected,
            normalizedInput: normalizedInput,
            isCorrect: isCorrect,
            promptShownAt: promptShownAt,
            submittedAt: now,
            elapsedMs: elapsedMs,
            replayCount: 0,
            playTraceJSON: "[]",
            errorType: isCorrect ? nil : "other"
        )
        modelContext.insert(attempt)
        try? modelContext.save()
    }

    private func updateRunningSessionSummary() {
        guard let sessionId = currentSessionId else { return }
        let fd = FetchDescriptor<DictationSession>(
            predicate: #Predicate<DictationSession> { $0.id == sessionId }
        )
        guard let session = try? modelContext.fetch(fd).first else { return }
        session.attemptedCount = correct + wrong
        session.correctCount = correct
        session.wrongCount = wrong
        try? modelContext.save()
    }

    private func finishCurrentSession(status: String) {
        guard let sessionId = currentSessionId else { return }
        let fd = FetchDescriptor<DictationSession>(
            predicate: #Predicate<DictationSession> { $0.id == sessionId }
        )
        guard let session = try? modelContext.fetch(fd).first else { return }
        session.attemptedCount = correct + wrong
        session.correctCount = correct
        session.wrongCount = wrong
        session.status = status
        session.endedAt = .now
        try? modelContext.save()
        currentSessionId = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        DictationSession.self,
        DictationAttemptLog.self,
        configurations: config
    )
    NavigationStack {
        DictationSessionView(
            unitIndex: 0,
            words: []
        )
    }
    .modelContainer(container)
    .environmentObject(DictationProgressStore())
}
