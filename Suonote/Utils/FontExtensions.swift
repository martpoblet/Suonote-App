import SwiftUI

// MARK: - App Typography
/// Piazzolla: Títulos, headlines, display, chord names
/// Manrope: Body, captions, UI elements

struct AppFonts {
    static let piazzolla = "Piazzolla"
    static let manrope = "Manrope"

    static func checkFonts() {
        #if DEBUG
        let piazzollaOK = UIFont(name: piazzolla, size: 12) != nil
        let manropeOK = UIFont(name: manrope, size: 12) != nil
        print("Piazzolla: \(piazzollaOK ? "✓" : "✗")")
        print("Manrope: \(manropeOK ? "✓" : "✗")")
        #endif
    }
}

// MARK: - Font Extension
extension Font {

    // MARK: - Piazzolla (Primary - Titles & Display)

    static func piazzolla(_ size: CGFloat) -> Font {
        .custom(AppFonts.piazzolla, size: size)
    }

    static func piazzollaItalic(_ size: CGFloat) -> Font {
        .custom(AppFonts.piazzolla, size: size).italic()
    }

    // MARK: - Manrope (Secondary - Body & UI)

    static func manrope(_ size: CGFloat) -> Font {
        .custom(AppFonts.manrope, size: size)
    }

    // MARK: - Display Sizes (Piazzolla)

    static var appHero: Font { piazzolla(120) }
    static var appMega: Font { piazzolla(72) }
    static var appJumbo: Font { piazzolla(60) }
    static var appGiant: Font { piazzolla(56) }
    static var appHuge: Font { piazzolla(48) }
    static var appXXL: Font { piazzolla(44) }
    static var appXL: Font { piazzolla(40) }
    static var appLG: Font { piazzolla(36) }
    static var appMD: Font { piazzolla(32) }
    static var appSM: Font { piazzolla(24) }

    // MARK: - Title Sizes (Piazzolla)

    static var delightDisplayLarge: Font { piazzolla(48) }
    static var delightDisplay: Font { piazzolla(40) }
    static var delightLargeTitle: Font { piazzolla(34) }
    static var delightTitle: Font { piazzolla(28) }
    static var delightTitle2: Font { piazzolla(22) }
    static var delightTitle3: Font { piazzolla(20) }

    // MARK: - Headline (Piazzolla for emphasis)

    static var delightHeadline: Font { piazzolla(17) }

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

    static func app(size: CGFloat) -> Font { piazzolla(size) }
    static func delight(size: CGFloat) -> Font { piazzolla(size) }
    static func appItalic(size: CGFloat) -> Font { piazzollaItalic(size) }
    static func delightItalic(size: CGFloat) -> Font { piazzollaItalic(size) }
    static func primary(size: CGFloat) -> Font { piazzolla(size) }
    static func secondary(size: CGFloat) -> Font { manrope(size) }
}

// MARK: - UIFont Extension
extension UIFont {
    static func piazzolla(_ size: CGFloat) -> UIFont {
        UIFont(name: AppFonts.piazzolla, size: size) ?? .systemFont(ofSize: size)
    }

    static func manrope(_ size: CGFloat) -> UIFont {
        UIFont(name: AppFonts.manrope, size: size) ?? .systemFont(ofSize: size)
    }

    static func app(size: CGFloat) -> UIFont { piazzolla(size) }
    static func delight(size: CGFloat) -> UIFont { piazzolla(size) }
}
