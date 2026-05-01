import SwiftData
import SwiftUI

struct DictationSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictationProgress: DictationProgressStore

    let unitIndex: Int
    let words: [VocabularyEntry]

    @State private var orderMode: DictationOrderMode = .random
    @State private var orderedUnitWords: [VocabularyEntry] = []
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var correct = 0
    @State private var wrong = 0
    @State private var sessionDone = false
    @State private var lastWasCorrect: Bool?
    @State private var showResultHint = false
    @State private var currentSessionId: UUID?
    @State private var promptShownAt: Date = .now
    @StateObject private var playbackEngine = DictationPlaybackEngine()
    @State private var isAutoMode = false
    @State private var autoPasses: [DictationPlaybackPass] = DictationTimingProfile.autoDefault.passes
    @State private var isAutoPlaybackStarted = false
    @State private var promptReplayCount = 0
    @State private var promptTraceEvents: [DictationPlaybackTraceEvent] = []
    @State private var isSessionActive = false
    @State private var playbackTask: Task<Void, Never>?
    /// Snapshotted logs for the summary UI (filled before `finishCurrentSession` clears `currentSessionId`).
    @State private var completedSessionAttempts: [DictationAttemptLog] = []
    @State private var showTranslationHint = false

    private let frenchCharacterRows: [[String]] = [
        ["à", "â", "æ", "ç", "é", "è", "ê", "ë"],
        ["î", "ï", "ô", "œ", "ù", "û", "ü", "ÿ"],
    ]

    private var activeWords: [VocabularyEntry] {
        orderedUnitWords
    }

    private var current: VocabularyEntry? {
        guard currentIndex < activeWords.count else { return nil }
        return activeWords[currentIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sessionDone {
                    sessionSummary
                } else if !isSessionActive {
                    preSessionSetup
                } else {
                    progressHeader
                    activeSessionControls
                    promptCard
                    frenchCharactersSection
                    if !isAutoMode {
                        nextWordSection
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Dictation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshOrderedWords()
            resetSession()
        }
        .onChange(of: sessionDone) { _, done in
            if done {
                let total = correct + wrong
                if let sid = currentSessionId {
                    let sessionIdConst = sid
                    let fd = FetchDescriptor<DictationAttemptLog>(
                        predicate: #Predicate<DictationAttemptLog> { log in log.sessionId == sessionIdConst },
                        sortBy: [SortDescriptor(\.promptIndex, order: .forward)]
                    )
                    completedSessionAttempts = (try? modelContext.fetch(fd)) ?? []
                } else {
                    completedSessionAttempts = []
                }
                dictationProgress.completeSession(
                    unitIndex: unitIndex,
                    correct: correct,
                    total: total,
                    modelContext: modelContext
                )
                finishCurrentSession(status: "completed")
            }
        }
        .onChange(of: currentIndex) { _, _ in
            showTranslationHint = false
            promptShownAt = .now
            resetPromptPlaybackState()
            if isAutoMode && isAutoPlaybackStarted {
                triggerPromptPlayback(isUserReplay: false)
            }
        }
        .onChange(of: orderMode) { _, _ in
            if isSessionActive && !sessionDone {
                finishCurrentSession(status: "abandoned")
            }
            refreshOrderedWords()
            resetSession()
        }
        .onChange(of: isAutoMode) { _, _ in
            // Mode switch must not auto-start auto playback.
            if !isAutoMode {
                isAutoPlaybackStarted = false
                playbackTask?.cancel()
                playbackTask = nil
                playbackEngine.stopCurrentPlayback()
            }
        }
        .onChange(of: autoPasses) { _, _ in
            // Editing auto timing should not reset current progress.
            if isSessionActive && !sessionDone && isAutoMode && isAutoPlaybackStarted {
                triggerPromptPlayback(isUserReplay: false)
            }
        }
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
            playbackEngine.stopCurrentPlayback()
            if isSessionActive && !sessionDone {
                dictationProgress.abandonSession(unitIndex: unitIndex, modelContext: modelContext)
                finishCurrentSession(status: "abandoned")
            }
        }
    }

    private var preSessionSetup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session setup")
                .font(.title3.weight(.semibold))

            controls

            Button {
                startNewSession()
            } label: {
                HStack {
                    Text("Start Dictation")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(.plain)
            .disabled(orderedUnitWords.isEmpty)
            .opacity(orderedUnitWords.isEmpty ? 0.5 : 1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var progressHeader: some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(currentIndex + 1), total: Double(max(1, activeWords.count)))
                .tint(.blue)
            Text("\(min(currentIndex + 1, activeWords.count))/\(activeWords.count)")
                .font(.headline)
                .foregroundStyle(.blue)
        }
        .padding(.top, 4)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $isAutoMode) {
                Text("Manual Mode").tag(false)
                Text("Auto Mode").tag(true)
            }
            .pickerStyle(.segmented)

            if isAutoMode {
                autoSequenceEditor
            }

            Picker("Order mode", selection: $orderMode) {
                ForEach(DictationOrderMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Words this session: \(orderedUnitWords.count) / \(orderedUnitWords.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Controls shown after session starts: keep mode/timing and word count, hide ordering.
    private var activeSessionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $isAutoMode) {
                Text("Manual Mode").tag(false)
                Text("Auto Mode").tag(true)
            }
            .pickerStyle(.segmented)

            if isAutoMode {
                autoSequenceEditor
            }

            Text("Words this session: \(orderedUnitWords.count) / \(orderedUnitWords.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var autoSequenceEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSessionActive {
                Button {
                    if isAutoPlaybackStarted {
                        pauseAutoPlayback()
                    } else {
                        isAutoPlaybackStarted = true
                        triggerPromptPlayback(isUserReplay: false)
                    }
                } label: {
                    HStack {
                        Image(systemName: isAutoPlaybackStarted ? "pause.fill" : "play.fill")
                        Text(isAutoPlaybackStarted ? "Pause Auto Play" : "Start Auto Play")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(autoPasses.indices, id: \.self) { idx in
                    HStack {
                        Text("Play \(idx + 1)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Menu {
                            ForEach(0...10, id: \.self) { sec in
                                Button("\(sec)s") {
                                    autoPasses[idx].delayAfterSeconds = Double(sec)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(Int(autoPasses[idx].delayAfterSeconds))s")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .frame(minWidth: 58)
                            .frame(height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private func manualMinePlaybackButton(for word: VocabularyEntry) -> some View {
        Button {
            triggerMinePlayback()
        } label: {
            Image(systemName: "mic.fill")
                .font(.title3)
                .foregroundStyle(hasMineRecording(for: word) ? .blue : .gray)
                .frame(width: 42, height: 42)
                .background(
                    Circle().stroke(
                        hasMineRecording(for: word) ? Color.blue.opacity(0.25) : Color.gray.opacity(0.35),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasMineRecording(for: word))
    }

    private var translationHintButton: some View {
        Button {
            showTranslationHint.toggle()
        } label: {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(showTranslationHint ? .white : .blue)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(showTranslationHint ? Color.blue : Color.blue.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(current == nil)
        .opacity(current == nil ? 0.4 : 1)
        .accessibilityLabel(showTranslationHint ? "Hide translation hint" : "Show English and Chinese translation")
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    triggerPromptPlayback(isUserReplay: true)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(current == nil)

                if !isAutoMode, let word = current {
                    manualMinePlaybackButton(for: word)
                }

                Spacer(minLength: 8)

                translationHintButton
            }

            TextField("Enter French text", text: $userInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if showTranslationHint, let word = current {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.english)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if let zh = word.chineseExplanation, !zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(zh)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                )
            }

            if let ok = lastWasCorrect, showResultHint {
                Text(ok ? "Correct" : "Incorrect")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ok ? .green : .red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var frenchCharactersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 8) {
                ForEach(frenchCharacterRows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { char in
                            Button(char) {
                                userInput.append(char)
                            }
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                }
            }
        }
    }

    private var nextWordSection: some View {
        Button {
            submitStep()
        } label: {
            HStack {
                Text("Next Word")
                    .font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .disabled(current == nil)
        .opacity(current == nil ? 0.5 : 1)
    }

    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 8) {
                Text("Session complete")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                Text("Correct: \(correct)   Wrong: \(wrong)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Button("Again") {
                    resetSession()
                    sessionDone = false
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            Text("Attempts (play order)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 12) {
                ForEach(Array(completedSessionAttempts.enumerated()), id: \.element.id) { offset, attempt in
                    DictationSessionCompleteAttemptRow(
                        displayIndex: offset + 1,
                        attempt: attempt,
                        glossaryWord: words.first(where: { $0.seedNumber == attempt.seedNumber }),
                        playTTS: { playLemmaTTS(for: attempt) },
                        playMine: { playLemmaMine(for: attempt) },
                        hasMineRecording: mineRecordingAvailableForSummary(for: attempt)
                    )
                }
            }
        }
    }

    /// French TTS for a row; resolves `VocabularyEntry` from session `words`.
    private func playLemmaTTS(for attempt: DictationAttemptLog) {
        guard let entry = words.first(where: { $0.seedNumber == attempt.seedNumber }) else { return }
        let profile = DictationTimingProfile(
            mode: "session_summary",
            passes: [DictationPlaybackPass(source: .tts, delayAfterSeconds: 0)]
        )
        Task {
            await playbackEngine.playProfile(word: entry, profile: profile) { _ in }
        }
    }

    private func playLemmaMine(for attempt: DictationAttemptLog) {
        guard let entry = words.first(where: { $0.seedNumber == attempt.seedNumber }),
              hasMineRecording(for: entry) else { return }
        let profile = DictationTimingProfile(
            mode: "session_summary_mine",
            passes: [DictationPlaybackPass(source: .mine, delayAfterSeconds: 0)]
        )
        Task {
            await playbackEngine.playProfile(word: entry, profile: profile) { _ in }
        }
    }

    private func mineRecordingAvailableForSummary(for attempt: DictationAttemptLog) -> Bool {
        guard let entry = words.first(where: { $0.seedNumber == attempt.seedNumber }) else { return false }
        return hasMineRecording(for: entry)
    }

    private func submitStep() {
        guard let w = current else { return }
        let ok = DictationNormalization.isMatch(userInput: userInput, expectedLemma: w.frenchLemma)
        lastWasCorrect = ok
        showResultHint = true
        if ok { correct += 1 } else { wrong += 1 }
        recordAttempt(for: w, isCorrect: ok)
        StudyEventLogger.record(
            modelContext: modelContext,
            seedNumber: w.seedNumber,
            eventType: StudyEventType.dictationSubmit,
            context: [
                "screen": "dictation_session",
                "correct": ok ? "true" : "false",
                "unit": String(unitIndex + 1),
                "orderMode": orderMode.rawValue,
                "autoMode": isAutoMode ? "true" : "false"
            ]
        )
        updateRunningSessionSummary()

        if currentIndex + 1 >= activeWords.count {
            sessionDone = true
            lastWasCorrect = nil
            return
        }
        currentIndex += 1
        userInput = ""
        lastWasCorrect = nil
        showResultHint = false
    }

    private func resetSession() {
        currentIndex = 0
        userInput = ""
        correct = 0
        wrong = 0
        lastWasCorrect = nil
        sessionDone = false
        completedSessionAttempts = []
        isSessionActive = false
        isAutoPlaybackStarted = false
        showResultHint = false
        showTranslationHint = false
        promptShownAt = .now
        resetPromptPlaybackState()
    }

    private func resetPromptPlaybackState() {
        promptReplayCount = 0
        promptTraceEvents = []
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
        isSessionActive = true
        isAutoPlaybackStarted = false
        let profile = timingProfileForCurrentMode()
        let session = DictationSession(
            sourceScope: "unit_\(unitIndex + 1)",
            orderMode: orderMode.rawValue,
            timingProfileJSON: profile.toJSON(),
            plannedCount: activeWords.count
        )
        modelContext.insert(session)
        try? modelContext.save()
        currentSessionId = session.id
        StudyEventLogger.record(
            modelContext: modelContext,
            seedNumber: 0,
            eventType: StudyEventType.dictationSessionStart,
            context: [
                "screen": "dictation_session",
                "unit": String(unitIndex + 1),
                "orderMode": orderMode.rawValue,
                "autoMode": isAutoMode ? "true" : "false",
                "plannedCount": String(activeWords.count)
            ]
        )
    }

    private func recordAttempt(for word: VocabularyEntry, isCorrect: Bool) {
        guard let sessionId = currentSessionId else { return }
        let now = Date()
        let elapsedMs = max(0, Int(now.timeIntervalSince(promptShownAt) * 1000.0))
        let normalizedExpected = DictationNormalization.normalize(word.frenchLemma)
        let normalizedInput = DictationNormalization.normalize(userInput)
        let traceJSON = promptTraceEvents.toJSON()
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
            replayCount: promptReplayCount,
            playTraceJSON: traceJSON,
            errorType: isCorrect ? nil : "other"
        )
        modelContext.insert(attempt)
        upsertWordStats(seedNumber: word.seedNumber, isCorrect: isCorrect, at: now)
        try? modelContext.save()
    }

    private func upsertWordStats(seedNumber: Int, isCorrect: Bool, at now: Date) {
        let fd = FetchDescriptor<DictationWordStats>(
            predicate: #Predicate<DictationWordStats> { $0.seedNumber == seedNumber }
        )
        let stats: DictationWordStats
        if let existing = try? modelContext.fetch(fd).first {
            stats = existing
        } else {
            stats = DictationWordStats(seedNumber: seedNumber)
            modelContext.insert(stats)
        }

        stats.attemptCount += 1
        stats.lastAttemptAt = now
        if isCorrect {
            stats.correctCount += 1
        } else {
            stats.wrongCount += 1
            stats.lastWrongAt = now
        }
    }

    private func playCurrentPrompt(isUserReplay: Bool) async {
        guard let word = current else { return }
        if isUserReplay {
            promptReplayCount += 1
        }
        let profile = timingProfileForCurrentMode()
        await playbackEngine.playProfile(word: word, profile: profile) { event in
            promptTraceEvents.append(event)
        }
        guard !Task.isCancelled else { return }
        if isAutoMode && isAutoPlaybackStarted && !isUserReplay && isSessionActive && !sessionDone {
            submitStep()
        }
    }

    /// Manual mode: play user “Mine” recording only (no TTS fallback path when button is enabled).
    private func playMinePrompt(isUserReplay: Bool) async {
        guard let word = current, hasMineRecording(for: word) else { return }
        if isUserReplay {
            promptReplayCount += 1
        }
        let profile = DictationTimingProfile(
            mode: "manual_mine",
            passes: [DictationPlaybackPass(source: .mine, delayAfterSeconds: 0)]
        )
        await playbackEngine.playProfile(word: word, profile: profile) { event in
            promptTraceEvents.append(event)
        }
    }

    private func hasMineRecording(for word: VocabularyEntry) -> Bool {
        guard let url = try? MinePronunciationStorage.fileURL(seedNumber: word.seedNumber),
              FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let n = attrs[.size] as? NSNumber else { return false }
        return n.uint64Value > 256
    }

    private func triggerMinePlayback() {
        guard let word = current, hasMineRecording(for: word) else { return }
        StudyEventLogger.record(
            modelContext: modelContext,
            seedNumber: word.seedNumber,
            eventType: StudyEventType.dictationReplay,
            context: [
                "screen": "dictation_session",
                "autoMode": "false",
                "source": "mine"
            ]
        )
        playbackTask?.cancel()
        playbackTask = Task {
            await playMinePrompt(isUserReplay: true)
        }
    }

    private func triggerPromptPlayback(isUserReplay: Bool) {
        if let word = current {
            StudyEventLogger.record(
                modelContext: modelContext,
                seedNumber: word.seedNumber,
                eventType: isUserReplay ? StudyEventType.dictationReplay : StudyEventType.dictationPromptPlay,
                context: [
                    "screen": "dictation_session",
                    "autoMode": isAutoMode ? "true" : "false"
                ]
            )
        }
        playbackTask?.cancel()
        playbackTask = Task {
            await playCurrentPrompt(isUserReplay: isUserReplay)
        }
    }

    private func pauseAutoPlayback() {
        isAutoPlaybackStarted = false
        playbackTask?.cancel()
        playbackTask = nil
        playbackEngine.stopCurrentPlayback()
    }

    private func timingProfileForCurrentMode() -> DictationTimingProfile {
        if isAutoMode {
            return DictationTimingProfile(mode: "auto", passes: autoPasses)
        }
        return DictationTimingProfile.manualDefault
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
        StudyEventLogger.record(
            modelContext: modelContext,
            seedNumber: 0,
            eventType: StudyEventType.dictationSessionEnd,
            context: [
                "screen": "dictation_session",
                "unit": String(unitIndex + 1),
                "status": status,
                "attempted": String(correct + wrong),
                "correct": String(correct),
                "wrong": String(wrong)
            ]
        )
        currentSessionId = nil
        isSessionActive = false
        isAutoPlaybackStarted = false
    }
}

private extension DictationTimingProfile {
    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

private extension Array where Element == DictationPlaybackTraceEvent {
    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        DictationSession.self,
        DictationAttemptLog.self,
        DictationWordStats.self,
        VocabularyStudyEvent.self,
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
