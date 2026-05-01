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
                        Text("Attempts (play order)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVStack(spacing: 8) {
                            ForEach(Array(attempts.enumerated()), id: \.element.id) { offset, attempt in
                                DictationSessionCompleteAttemptRow(
                                    displayIndex: offset + 1,
                                    attempt: attempt,
                                    glossaryWord: words.first(where: { $0.seedNumber == attempt.seedNumber }),
                                    playTTS: { playLemmaTTS(for: attempt) }
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
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
            Text((session.endedAt ?? session.startedAt).formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            Text("Correct: \(session.correctCount)   Wrong: \(session.wrongCount)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            if !session.orderMode.isEmpty {
                Text("Order: \(session.orderMode)")
                    .font(.caption2)
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
}

/// Shared row with live session complete summary (`DictationSessionView`).
struct DictationSessionCompleteAttemptRow: View {
    let displayIndex: Int
    let attempt: DictationAttemptLog
    let glossaryWord: VocabularyEntry?
    let playTTS: () -> Void

    private var typedDisplay: String {
        let t = attempt.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "—" : t
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(displayIndex)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(attempt.expectedLemma)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if attempt.isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                }
                if let gloss = glossaryWord, !gloss.english.isEmpty {
                    Text(gloss.english)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Group {
                    if attempt.isCorrect {
                        Text("Matched the lemma.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You typed")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(typedDisplay)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: playTTS) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(glossaryWord == nil ? .gray : .blue)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().stroke(
                            (glossaryWord == nil ? Color.gray : Color.blue).opacity(0.2),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(glossaryWord == nil)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let result = attempt.isCorrect ? "correct" : "incorrect"
        if attempt.isCorrect {
            return "Word \(displayIndex): \(attempt.expectedLemma), \(result)."
        }
        return "Word \(displayIndex): expected \(attempt.expectedLemma), you typed \(typedDisplay), \(result)."
    }
}
