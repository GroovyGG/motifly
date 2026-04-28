import SwiftUI

struct SettingsView: View {
    @AppStorage("motifly.settings.autoPlayDefault") private var autoPlayDefault = false
    @AppStorage("motifly.settings.showChineseTranslation") private var showChineseTranslation = true
    @AppStorage("motifly.settings.dailyGoalMinutes") private var dailyGoalMinutes = 30
    @AppStorage("motifly.settings.weeklyGoalHours") private var weeklyGoalHours = 5
    @AppStorage("motifly.settings.themeColor") private var themeColorName = "Blue"
    @AppStorage("motifly.settings.remindersEnabled") private var remindersEnabled = true
    @State private var reminderTime: Date = {
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        return Calendar.current.date(from: components) ?? .now
    }()
    @State private var reminderDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri

    private let themeColors: [(name: String, color: Color)] = [
        ("Blue", .blue),
        ("Indigo", .indigo),
        ("Purple", .purple),
        ("Green", .green),
        ("Teal", .teal),
        ("Orange", .orange),
        ("Pink", .pink),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                goalsCard
                themeCard
                reminderCard
                preferencesCard
                aboutCard
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsHeader(icon: "target", title: "Goals", subtitle: "Set your study goals")

            goalRow(
                icon: "clock",
                title: "Daily Goal",
                subtitle: "Study time",
                valueText: "\(dailyGoalMinutes)",
                unitText: "min/day",
                minText: "10 min",
                maxText: "120 min",
                value: $dailyGoalMinutes,
                range: 10...120
            )

            goalRow(
                icon: "book",
                title: "Weekly Goal",
                subtitle: "Study time",
                valueText: "\(weeklyGoalHours)",
                unitText: "h/week",
                minText: "1 h",
                maxText: "20 h",
                value: $weeklyGoalHours,
                range: 1...20
            )

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("Goals help you stay consistent.\nYou can update them anytime.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .cardStyle()
    }

    private func goalRow(
        icon: String,
        title: String,
        subtitle: String,
        valueText: String,
        unitText: String,
        minText: String,
        maxText: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.caption)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    stepButton(systemName: "minus") { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1) }
                    Text(valueText)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.blue)
                        .frame(minWidth: 30)
                    Text(unitText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    stepButton(systemName: "plus") { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1) }
                }
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .tint(.blue)
            HStack {
                Text(minText)
                Spacer()
                Text(maxText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsHeader(icon: "paintpalette", title: "Theme Color", subtitle: "Choose your accent color")
            HStack(spacing: 10) {
                ForEach(themeColors, id: \.name) { item in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if themeColorName == item.name {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .padding(2)
                                }
                            }
                            .onTapGesture {
                                themeColorName = item.name
                            }
                        Text(item.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle()
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                settingsHeader(icon: "bell", title: "Reminders", subtitle: "Get notified to keep your streak going")
                Spacer()
                Toggle("", isOn: $remindersEnabled)
                    .labelsHidden()
            }

            HStack {
                Text("Daily Reminder")
                Spacer()
                DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .disabled(!remindersEnabled)
            }
            .font(.caption2)

            HStack {
                Text("Reminder Days")
                    .font(.caption2)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(Array(zip(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], 2...8)), id: \.1) { item in
                        let selected = reminderDays.contains(item.1)
                        Text(item.0)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(selected ? .blue : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selected ? Color.blue.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                            )
                            .onTapGesture {
                                if selected { reminderDays.remove(item.1) } else { reminderDays.insert(item.1) }
                            }
                    }
                }
                .disabled(!remindersEnabled)
            }
        }
        .cardStyle()
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsHeader(icon: "slider.horizontal.3", title: "Study Preferences", subtitle: "Customize your learning experience")
            toggleRow(
                title: "Auto-play Pronunciation",
                subtitle: "Automatically play pronunciation audio",
                isOn: $autoPlayDefault
            )
            Divider()
            toggleRow(
                title: "Show Translation",
                subtitle: "Show translation after answering",
                isOn: $showChineseTranslation
            )
        }
        .cardStyle()
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private var aboutCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                DebugStudyTimelineView()
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("About")
                            .font(.subheadline.weight(.semibold))
                        Text("App information and support")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private func settingsHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
