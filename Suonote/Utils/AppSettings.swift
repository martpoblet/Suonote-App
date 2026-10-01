import SwiftUI
import Observation

/// Global app settings stored in UserDefaults (U-02, U-01)
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    enum AppTheme: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }

        /// Localized display name (rawValue is persisted — never translate it).
        var title: String {
            switch self {
            case .system: return String(localized: "System")
            case .light: return String(localized: "Light")
            case .dark: return String(localized: "Dark")
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max"
            case .dark: return "moon"
            }
        }
    }
    
    /// In-app language override. `.system` follows the device language.
    enum AppLanguage: String, CaseIterable {
        case system
        case english = "en"
        case spanish = "es"

        /// Shown in each language's own name so it's always recognisable.
        var title: String {
            switch self {
            case .system: return String(localized: "System")
            case .english: return "English"
            case .spanish: return "Español"
            }
        }

        /// Locale to inject into the SwiftUI environment (nil = device locale).
        var locale: Locale? {
            switch self {
            case .system: return nil
            case .english, .spanish: return Locale(identifier: rawValue)
            }
        }
    }

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }
    
    var showOnboarding: Bool {
        didSet { UserDefaults.standard.set(showOnboarding, forKey: "showOnboarding") }
    }
    
    /// Whether to show Roman numerals on chord chips
    var showRomanNumerals: Bool {
        didSet { UserDefaults.standard.set(showRomanNumerals, forKey: "showRomanNumerals") }
    }
    
    /// Whether to show Nashville numbers on chord chips
    var showNashvilleNumbers: Bool {
        didSet { UserDefaults.standard.set(showNashvilleNumbers, forKey: "showNashvilleNumbers") }
    }
    
    /// Language override. Bundle localization is resolved at launch from
    /// `AppleLanguages`, so a change fully applies the next time the app opens.
    var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            Self.applyLanguageOverride(appLanguage)
        }
    }

    private static func applyLanguageOverride(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    private init() {
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? "System"
        self.theme = AppTheme(rawValue: themeRaw) ?? .system
        
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        self.showOnboarding = !hasLaunched
        
        self.showRomanNumerals = UserDefaults.standard.bool(forKey: "showRomanNumerals")
        self.showNashvilleNumbers = UserDefaults.standard.bool(forKey: "showNashvilleNumbers")

        let languageRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        self.appLanguage = AppLanguage(rawValue: languageRaw) ?? .system
    }
    
    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
}
