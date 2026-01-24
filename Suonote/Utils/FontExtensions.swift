import SwiftUI

// MARK: - App Typography
/// Erode: Títulos, headlines, display, chord names
/// Manrope: Body, captions, UI elements

struct AppFonts {
    static let erode = "Erode Variable"
    static let manrope = "Manrope"

    static func checkFonts() {
        #if DEBUG
        let erodeOK = UIFont(name: erode, size: 12) != nil
        let manropeOK = UIFont(name: manrope, size: 12) != nil
        print("Erode: \(erodeOK ? "✓" : "✗")")
        print("Manrope: \(manropeOK ? "✓" : "✗")")
        #endif
    }
}

// MARK: - Font Extension
extension Font {

    // MARK: - Erode (Primary - Titles & Display)

    static func erode(_ size: CGFloat) -> Font {
        .custom(AppFonts.erode, size: size)
    }

    static func erodeItalic(_ size: CGFloat) -> Font {
        .custom(AppFonts.erode, size: size).italic()
    }

    // MARK: - Manrope (Secondary - Body & UI)

    static func manrope(_ size: CGFloat) -> Font {
        .custom(AppFonts.manrope, size: size)
    }

    // MARK: - Display Sizes (Erode)

    static var appHero: Font { erode(120) }
    static var appMega: Font { erode(72) }
    static var appJumbo: Font { erode(60) }
    static var appGiant: Font { erode(56) }
    static var appHuge: Font { erode(48) }
    static var appXXL: Font { erode(44) }
    static var appXL: Font { erode(40) }
    static var appLG: Font { erode(36) }
    static var appMD: Font { erode(32) }
    static var appSM: Font { erode(24) }

    // MARK: - Title Sizes (Erode)

    static var delightDisplayLarge: Font { erode(48) }
    static var delightDisplay: Font { erode(40) }
    static var delightLargeTitle: Font { erode(34) }
    static var delightTitle: Font { erode(28) }
    static var delightTitle2: Font { erode(22) }
    static var delightTitle3: Font { erode(20) }

    // MARK: - Headline (Erode for emphasis)

    static var delightHeadline: Font { erode(17) }

    // MARK: - Body Sizes (Manrope)

    static var delightSubheadline: Font { manrope(15) }
    static var delightBody: Font { manrope(15) }
    static var delightBodyBold: Font { manrope(15) }
    static var delightBodyMedium: Font { manrope(15) }

    // MARK: - Small Sizes (Manrope)

    static var delightCallout: Font { manrope(13) }
    static var delightCalloutBold: Font { manrope(13) }
    static var delightCaption: Font { manrope(12) }
    static var delightCaption2: Font { manrope(11) }
    static var delightFootnote: Font { manrope(13) }
    static var appMicro: Font { manrope(10) }
    static var appNano: Font { manrope(8) }

    // MARK: - Legacy aliases

    static func app(size: CGFloat) -> Font { erode(size) }
    static func delight(size: CGFloat) -> Font { erode(size) }
    static func appItalic(size: CGFloat) -> Font { erodeItalic(size) }
    static func delightItalic(size: CGFloat) -> Font { erodeItalic(size) }
    static func primary(size: CGFloat) -> Font { erode(size) }
    static func secondary(size: CGFloat) -> Font { manrope(size) }
}

// MARK: - UIFont Extension
extension UIFont {
    static func erode(_ size: CGFloat) -> UIFont {
        UIFont(name: AppFonts.erode, size: size) ?? .systemFont(ofSize: size)
    }

    static func manrope(_ size: CGFloat) -> UIFont {
        UIFont(name: AppFonts.manrope, size: size) ?? .systemFont(ofSize: size)
    }

    static func app(size: CGFloat) -> UIFont { erode(size) }
    static func delight(size: CGFloat) -> UIFont { erode(size) }
}
