import SwiftUI

/// Placeholder hub for utilities (pronunciation aids, converters, etc.).
struct ToolView: View {
    private let tools: [(id: Int, title: String, detail: String, symbol: String)] = [
        (1, "French pronunciation", "IPA chart with examples and audio", "waveform"),
        (2, "Tool 2", "Placeholder — coming soon", "slider.horizontal.3"),
        (3, "Tool 3", "Placeholder — coming soon", "square.grid.2x2")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap a tool to open it when available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    ForEach(tools, id: \.id) { tool in
                        if tool.id == 1 {
                            NavigationLink {
                                FrenchPronunciationToolView()
                            } label: {
                                toolRow(title: tool.title, detail: tool.detail, symbol: tool.symbol, showChevron: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            toolRow(title: tool.title, detail: tool.detail, symbol: tool.symbol, showChevron: true)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Tool")
        .navigationBarTitleDisplayMode(.large)
    }

    private func toolRow(title: String, detail: String, symbol: String, showChevron: Bool = true) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.gradient)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

#Preview {
    NavigationStack {
        ToolView()
    }
}
