import SwiftUI

/// P0 design tokens. Prefer these over ad hoc literals so Figma Variables and Swift stay aligned
/// (see `docs/superpowers/specs/2026-05-02-motifly-p0-design-tokens.md`).
enum MotiflyTokens {

    /// Bundled **Josefin Sans** variable font (`Fonts/JosefinSans-Variable.ttf`, OFL). Use `TypeStyle.font(_:weight:)`.
    enum Typeface {
        static let familyName = "Josefin Sans"
    }

    enum Colors {
        static var screenBackground: Color { Color(.systemGroupedBackground) }
        static var cardSurface: Color { Color(.secondarySystemGroupedBackground) }

        static var accentPrimary: Color { Color.accentColor }
        static var textPrimary: Color { Color.primary }
        static var textSecondary: Color { Color.secondary }
        static var textTertiary: Color { Color(.tertiaryLabel) }

        /// Dictation tab: dark uses grouped background; light uses tinted blue-gray.
        static func dictationScreenBackground(_ scheme: ColorScheme) -> Color {
            if scheme == .dark { return Color(.systemGroupedBackground) }
            return dictationScreenLightTint
        }

        private static var dictationScreenLightTint: Color {
            Color(red: 0.93, green: 0.95, blue: 0.98)
        }

        /// Verb headword green (prototype `text-green-700` / dark companion).
        static func lemmaVerb(for scheme: ColorScheme) -> Color {
            if scheme == .dark {
                return Color(red: 0.38, green: 0.82, blue: 0.55)
            }
            return Color(red: 0.09, green: 0.50, blue: 0.26)
        }

        /// Memory / warm support blocks: light warm yellow; dark secondary grouped.
        static func surfaceElevated(for scheme: ColorScheme) -> Color {
            if scheme == .dark { return Color(.secondarySystemGroupedBackground) }
            return Color(red: 1, green: 0.96, blue: 0.82)
        }
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 14
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let sectionBottom: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let card: CGFloat = 14
        static let lg: CGFloat = 16
        static let pill: CGFloat = 18
        static let dictationHeader: CGFloat = 20
    }

    /// Josefin Sans mapped to Dynamic Type text styles (variable font respects `.weight`).
    enum TypeStyle {
        /// Base API: pair with `Font.TextStyle` for scaling; weights map to the variable font axis.
        static func font(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
            Font.custom(Typeface.familyName, size: basePointSize(for: textStyle), relativeTo: textStyle)
                .weight(weight)
        }

        private static func basePointSize(for textStyle: Font.TextStyle) -> CGFloat {
            switch textStyle {
            case .largeTitle: return 34
            case .title: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline: return 17
            case .body: return 17
            case .callout: return 16
            case .subheadline: return 15
            case .footnote: return 13
            case .caption: return 12
            case .caption2: return 11
            @unknown default: return 17
            }
        }

        static var screenTitle: Font { font(.title3, weight: .bold) }
        static var sectionTitle: Font { font(.headline, weight: .semibold) }
        static var statValue: Font { font(.title3, weight: .semibold) }
        static var body: Font { font(.body) }
        static var callout: Font { font(.callout) }
        static var rowPrimary: Font { font(.subheadline) }
        static var caption: Font { font(.caption) }
        static var captionSecondary: Font { font(.caption2) }
    }
}
