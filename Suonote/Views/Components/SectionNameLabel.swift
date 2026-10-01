import SwiftUI

/// A section name that degrades gracefully in narrow arrangement blocks:
/// full name → musician's abbreviation (Ch, Br, Pre…) → initial,
/// instead of truncating to "Cho…".
struct SectionNameLabel: View {
    let name: String
    var font: Font = DesignSystem.Typography.chordSmall
    var color: Color = DesignSystem.Colors.textPrimary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            label(name)
            label(Self.abbreviation(for: name))
            label(String(Self.abbreviation(for: name).prefix(1)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    static func abbreviation(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        // Keep a trailing number ("Verse 2" → "V2").
        let number = trimmed.split(separator: " ").last.flatMap { Int($0) }.map(String.init) ?? ""
        let known: [(String, String)] = [
            ("pre-chorus", "Pre"), ("prechorus", "Pre"), ("pre chorus", "Pre"),
            ("post-chorus", "Post"), ("chorus", "Ch"), ("hook", "Hk"),
            ("verse", "V"), ("bridge", "Br"), ("intro", "In"), ("outro", "Out"),
            ("interlude", "Int"), ("breakdown", "Bd"), ("solo", "Solo"), ("drop", "Drop"), ("loop", "Lp")
        ]
        for (key, short) in known where lower.hasPrefix(key) {
            return short + number
        }
        return String(trimmed.prefix(3))
    }
}
