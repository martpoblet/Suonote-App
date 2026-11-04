import Foundation

/// Decides when it is a good moment to invite the user to rate Suonote.
///
/// The invitation is a quiet card in the Library (never a blocking alert) and only
/// appears after the person has actually used the app: several launches and a few
/// songs. After it is answered or dismissed it stays away for a long time, and never
/// shows twice for the same app version.
enum ReviewPrompt {
    /// Numeric App Store ID of Suonote (the digits in `apps.apple.com/app/id<ID>`).
    /// Leave `nil` until the app has an ID: the card then uses the system rating
    /// dialog. With an ID, "Rate" opens the App Store review screen directly, which
    /// always works (the system dialog is rate-limited by Apple).
    static let appStoreID: String? = "6758340405"

    static let minimumLaunches = 5
    static let minimumSongs = 2
    static let cooldownDays = 120

    private enum Key {
        static let launches = "reviewPrompt.launchCount"
        static let lastAsked = "reviewPrompt.lastAskedDate"
        static let lastVersion = "reviewPrompt.lastAskedVersion"
    }

    private static var defaults: UserDefaults { .standard }

    /// Call once per app launch.
    static func recordLaunch() {
        defaults.set(defaults.integer(forKey: Key.launches) + 1, forKey: Key.launches)
    }

    /// Whether the card should be shown right now.
    static func shouldAsk(songCount: Int, now: Date = Date(), appVersion: String = currentVersion) -> Bool {
        guard defaults.integer(forKey: Key.launches) >= minimumLaunches else { return false }
        guard songCount >= minimumSongs else { return false }
        guard defaults.string(forKey: Key.lastVersion) != appVersion else { return false }
        if let last = defaults.object(forKey: Key.lastAsked) as? Date {
            let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            guard days >= cooldownDays else { return false }
        }
        return true
    }

    /// Call when the card is answered or dismissed so it does not come back soon.
    static func markAsked(now: Date = Date(), appVersion: String = currentVersion) {
        defaults.set(now, forKey: Key.lastAsked)
        defaults.set(appVersion, forKey: Key.lastVersion)
    }

    /// Direct link to the App Store "write a review" screen, when the ID is known.
    static var writeReviewURL: URL? {
        guard let appStoreID, !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
