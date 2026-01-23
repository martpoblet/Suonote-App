import SwiftUI

// MARK: - App Typography
/// Piazzolla: Títulos y display
/// Manrope: Body y textos pequeños

struct AppFonts {
    // Los nombres PostScript de las fuentes variables de Google Fonts
    static let piazzolla = "Piazzolla"
    static let manrope = "Manrope"

    /// Debug: Imprime todas las fuentes instaladas para encontrar los nombres correctos
    static func printAvailableFonts() {
        print("\n=== FUENTES DISPONIBLES ===")
        for family in UIFont.familyNames.sorted() {
            print("\nFamily: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  → \(name)")
            }
        }
        print("\n===========================\n")
    }

    /// Verifica si las fuentes están cargadas
    static func checkFonts() {
        let piazzollaOK = UIFont(name: piazzolla, size: 12) != nil
        let manropeOK = UIFont(name: manrope, size: 12) != nil
        print("Piazzolla: \(piazzollaOK ? "✓" : "✗")")
        print("Manrope: \(manropeOK ? "✓" : "✗")")

        if !piazzollaOK || !manropeOK {
            print("\n⚠️ Alguna fuente no carga. Ejecuta AppFonts.printAvailableFonts() para ver los nombres correctos")
        }
    }
}

// MARK: - Font Extension
extension Font {

    // MARK: - Primary (Piazzolla) - Títulos

    static func piazzolla(_ size: CGFloat) -> Font {
        .custom(AppFonts.piazzolla, size: size)
    }

    // MARK: - Secondary (Manrope) - Body

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

    // MARK: - Body Sizes (Manrope)

    static var delightHeadline: Font { manrope(17) }
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
    static func appItalic(size: CGFloat) -> Font { piazzolla(size).italic() }
    static func delightItalic(size: CGFloat) -> Font { piazzolla(size).italic() }
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
