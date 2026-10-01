import SwiftUI
import os

// MARK: - App Typography
/// Suonote speaks in two voices:
/// - **Erode** (serif) — the brand voice. Titles, display numerals (BPM, key),
///   chord names, section names, editorial italics.
/// - **Manrope** (sans) — the working voice. Labels, buttons, captions, body.
///
/// Both families ship as *variable* fonts whose default instance is the
/// lightest weight. `Font.custom(...).weight(...)` is unreliable with variable
/// fonts (and `.italic()` only synthesizes a slant), so every weight below
/// resolves to the font's real named instance by PostScript name.

struct AppFonts {
    static let erode = "Erode Variable"
    static let manrope = "Manrope"

    static func checkFonts() {
        #if DEBUG
        let missing = (ErodeWeight.allCases.map(\.postScriptName)
            + ErodeWeight.allCases.map(\.italicPostScriptName)
            + ManropeWeight.allCases.map(\.postScriptName))
            .filter { UIFont(name: $0, size: 12) == nil }
        if missing.isEmpty {
            AppLog.ui.debug("Brand fonts OK")
        } else {
            AppLog.ui.error("Missing font instances: \(missing.joined(separator: ", "))")
        }
        #endif
    }
}

enum ErodeWeight: CaseIterable {
    case light, regular, medium, semibold, bold

    var postScriptName: String {
        switch self {
        case .light: return "Erode-Variable-Light"
        case .regular: return "Erode-Variable-Light_Regular"
        case .medium: return "Erode-Variable-Light_Medium"
        case .semibold: return "Erode-Variable-Light_Semibold"
        case .bold: return "Erode-Variable-Light_Bold"
        }
    }

    var italicPostScriptName: String {
        switch self {
        case .light: return "Erode-Variable-Light-Italic"
        case .regular: return "Erode-Variable-Light-Italic_Italic"
        case .medium: return "Erode-Variable-Light-Italic_Medium-Italic"
        case .semibold: return "Erode-Variable-Light-Italic_Semibold-Italic"
        case .bold: return "Erode-Variable-Light-Italic_Bold-Italic"
        }
    }
}

enum ManropeWeight: CaseIterable {
    case light, regular, medium, semibold, bold, extrabold

    var postScriptName: String {
        switch self {
        case .light: return "Manrope-Light"
        case .regular: return "Manrope-Regular"
        case .medium: return "Manrope-Medium"
        case .semibold: return "Manrope-SemiBold"
        case .bold: return "Manrope-Bold"
        case .extrabold: return "Manrope-ExtraBold"
        }
    }
}

// MARK: - Font Extension
extension Font {

    /// Maps a design size to the closest system text style so custom fonts
    /// scale with Dynamic Type.
    static func inferredTextStyle(for size: CGFloat) -> TextStyle {
        switch size {
        case ..<11: return .caption2
        case ..<13: return .caption
        case ..<14: return .footnote
        case ..<16: return .body
        case ..<18: return .callout
        case ..<20: return .headline
        case ..<24: return .title3
        case ..<30: return .title2
        case ..<36: return .title
        default: return .largeTitle
        }
    }

    // MARK: Erode (brand serif)

    static func erode(
        _ size: CGFloat,
        weight: ErodeWeight = .regular,
        relativeTo style: TextStyle? = nil
    ) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style ?? inferredTextStyle(for: size))
    }

    /// True Erode italic (not a synthesized slant) — for editorial accents.
    static func erodeItalic(
        _ size: CGFloat,
        weight: ErodeWeight = .regular,
        relativeTo style: TextStyle? = nil
    ) -> Font {
        .custom(weight.italicPostScriptName, size: size, relativeTo: style ?? inferredTextStyle(for: size))
    }

    // MARK: Manrope (UI sans)

    static func manrope(
        _ size: CGFloat,
        weight: ManropeWeight = .regular,
        relativeTo style: TextStyle? = nil
    ) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style ?? inferredTextStyle(for: size))
    }

    // MARK: Legacy aliases (kept so older call sites compile)

    static var appHero: Font { erode(120, weight: .semibold) }
    static var appMega: Font { erode(72, weight: .semibold) }
    static var appJumbo: Font { erode(60, weight: .semibold) }
    static var appGiant: Font { erode(56, weight: .semibold) }
    static var appHuge: Font { erode(48, weight: .semibold) }
    static var appXXL: Font { erode(44, weight: .medium) }
    static var appXL: Font { erode(40, weight: .medium) }
    static var appLG: Font { erode(36, weight: .medium) }
    static var appMD: Font { erode(32, weight: .medium) }
    static var appSM: Font { erode(24, weight: .medium) }

    static func app(size: CGFloat) -> Font { erode(size, weight: .semibold) }
    static func appItalic(size: CGFloat) -> Font { erodeItalic(size) }
}

// MARK: - UIFont Extension
extension UIFont {
    static func erode(_ size: CGFloat, weight: ErodeWeight = .semibold) -> UIFont {
        UIFont(name: weight.postScriptName, size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    static func manrope(_ size: CGFloat, weight: ManropeWeight = .medium) -> UIFont {
        UIFont(name: weight.postScriptName, size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }
}
