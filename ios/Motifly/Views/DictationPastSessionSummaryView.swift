import SwiftData
import SwiftUI

/// Read-only dictation finish summary for a past **completed** session (same rows as live session complete).
struct DictationPastSessionSummaryView: View {
    let groupNumber: Int
    let words: [VocabularyEntry]

    @Environment(\.modelContext) private var modelContext
    @StateObject private var playbackEngine = DictationPlaybackEngine()
    @State private var session: DictationSession?
    @State private var attempts: [DictationAttemptLog] = []
    @State private var didLoad = false

    var body: some View {
        Group {
            if !didLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryHeaderCard(session: session)
                        Text("Attempts (mistakes first)")
                            .font(MotiflyTokens.TypeStyle.font(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVStack(spacing: 12) {
                            ForEach(Array(attempts.orderedForDictationSessionSummary().enumerated()), id: \.element.id) { offset, attempt in
                                DictationSessionCompleteAttemptRow(
                                    displayIndex: offset + 1,
                                    attempt: attempt,
                                    glossaryWord: words.first(where: { $0.seedNumber == attempt.seedNumber }),
                                    playTTS: { playLemmaTTS(for: attempt) },
                                    playMine: { playLemmaMine(for: attempt) },
                                    hasMineRecording: mineRecordingAvailable(for: attempt)
                                )
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            } else {
                ContentUnavailableView(
                    "No finished session yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Complete a dictation run for this group to see the summary here.")
                )
            }
        }
        .navigationTitle("Last summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadLastCompletedSession)
        .onDisappear {
            playbackEngine.stopCurrentPlayback()
        }
    }

    private func summaryHeaderCard(session: DictationSession) -> some View {
        VStack(spacing: 8) {
            Text("Session summary")
                .font(MotiflyTokens.TypeStyle.statValue)
                .frame(maxWidth: .infinity)
            Text((session.endedAt ?? session.startedAt).formatted(date: .abbreviated, time: .shortened))
                .font(MotiflyTokens.TypeStyle.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            Text("Correct: \(session.correctCount)   Wrong: \(session.wrongCount)")
                .font(MotiflyTokens.TypeStyle.font(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            if !session.orderMode.isEmpty {
                Text("Order: \(session.orderMode)")
                    .font(MotiflyTokens.TypeStyle.captionSecondary)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func loadLastCompletedSession() {
        defer { didLoad = true }
        let unitScope = "unit_\(groupNumber)"
        let fd = FetchDescriptor<DictationSession>(
            predicate: #Predicate<DictationSession> { s in
                s.sourceScope == unitScope && s.status == "completed"
            }
        )
        guard let list = try? modelContext.fetch(fd),
              let last = list.max(by: { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }) else {
            session = nil
            attempts = []
            return
        }
        session = last
        let sessionIdConst = last.id
        let fdAttempts = FetchDescriptor<DictationAttemptLog>(
            predicate: #Predicate<DictationAttemptLog> { log in log.sessionId == sessionIdConst },
            sortBy: [SortDescriptor(\.promptIndex, order: .forward)]
        )
        attempts = (try? modelContext.fetch(fdAttempts)) ?? []
    }

    private func playLemmaTTS(for attempt: DictationAttemptLog) {
        guard let entry = words.first(where: { $0.seedNumber == attempt.seedNumber }) else { return }
        let profile = DictationTimingProfile(
            mode: "past_session_summary",
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
            mode: "past_session_summary_mine",
            passes: [DictationPlaybackPass(source: .mine, delayAfterSeconds: 0)]
        )
        Task {
            await playbackEngine.playProfile(word: entry, profile: profile) { _ in }
        }
    }

    private func mineRecordingAvailable(for attempt: DictationAttemptLog) -> Bool {
        guard let entry = words.first(where: { $0.seedNumber == attempt.seedNumber }) else { return false }
        return hasMineRecording(for: entry)
    }

    private func hasMineRecording(for entry: VocabularyEntry) -> Bool {
        guard let url = try? MinePronunciationStorage.fileURL(seedNumber: entry.seedNumber),
              FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let n = attrs[.size] as? NSNumber else { return false }
        return n.uint64Value > 256
    }
}

/// Shared row with live session complete summary (`DictationSessionView`).
struct DictationSessionCompleteAttemptRow: View {
    let displayIndex: Int
    let attempt: DictationAttemptLog
    let glossaryWord: VocabularyEntry?
    let playTTS: () -> Void
    let playMine: () -> Void
    let hasMineRecording: Bool

    private var typedDisplay: String {
        let t = attempt.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "—" : t
    }

    private var canPlayTTS: Bool {
        glossaryWord != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(displayIndex)")
                .font(MotiflyTokens.TypeStyle.font(.subheadline, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(attempt.expectedLemma)
                        .font(MotiflyTokens.TypeStyle.font(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if attempt.isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .font(MotiflyTokens.TypeStyle.font(.subheadline, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(MotiflyTokens.TypeStyle.font(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.9))
                    }
                }

                if let gloss = glossaryWord, !gloss.english.isEmpty {
                    Text(gloss.english)
                        .font(MotiflyTokens.TypeStyle.captionSecondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if attempt.isCorrect {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(MotiflyTokens.TypeStyle.font(.caption, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("Matched the lemma.")
                            .font(MotiflyTokens.TypeStyle.font(.caption, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 2)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        mistakeFeedbackBox(title: "Mistaken", value: typedDisplay, tint: .red)
                        mistakeFeedbackBox(title: "Correct", value: attempt.expectedLemma, tint: .blue)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                summaryAudioCircleButton(
                    systemName: "speaker.wave.2.fill",
                    isEnabled: canPlayTTS,
                    action: playTTS
                )
                summaryAudioCircleButton(
                    systemName: "mic.fill",
                    isEnabled: hasMineRecording,
                    action: playMine
                )
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func mistakeFeedbackBox(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MotiflyTokens.TypeStyle.font(.caption2, weight: .semibold))
                .foregroundStyle(tint.opacity(0.85))
            Text(value)
                .font(MotiflyTokens.TypeStyle.font(.caption, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private func summaryAudioCircleButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(MotiflyTokens.TypeStyle.font(.caption, weight: .semibold))
                .foregroundStyle(isEnabled ? .blue : .gray)
                .frame(width: 30, height: 30)
                .background(
                    Circle().stroke(
                        isEnabled ? Color.blue.opacity(0.22) : Color.gray.opacity(0.35),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var accessibilitySummary: String {
        let result = attempt.isCorrect ? "correct" : "incorrect"
        if attempt.isCorrect {
            return "Word \(displayIndex): \(attempt.expectedLemma), \(result)."
        }
        return "Word \(displayIndex): expected \(attempt.expectedLemma), mistaken \(typedDisplay), \(result)."
    }
}

// MARK: - Session summary ordering (live + past “Last summary”)

extension Array where Element == DictationAttemptLog {
    /// Incorrect attempts first (`promptIndex`, then `submittedAt`), then correct — same order as end-of-session summary.
    func orderedForDictationSessionSummary() -> [DictationAttemptLog] {
        func byPromptOrder(_ a: DictationAttemptLog, _ b: DictationAttemptLog) -> Bool {
            if a.promptIndex != b.promptIndex { return a.promptIndex < b.promptIndex }
            return a.submittedAt < b.submittedAt
        }
        return filter { !$0.isCorrect }.sorted(by: byPromptOrder) + filter(\.isCorrect).sorted(by: byPromptOrder)
    }
}
