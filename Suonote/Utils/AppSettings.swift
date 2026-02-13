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
    
    private init() {
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? "light"
        self.theme = AppTheme(rawValue: themeRaw) ?? .light
        
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        self.showOnboarding = !hasLaunched
        
        self.showRomanNumerals = UserDefaults.standard.bool(forKey: "showRomanNumerals")
        self.showNashvilleNumbers = UserDefaults.standard.bool(forKey: "showNashvilleNumbers")
    }
    
    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
}
