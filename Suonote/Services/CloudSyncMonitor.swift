import Foundation
import CoreData
import CloudKit
import Combine

/// Keys used by sync UI/state persisted in UserDefaults.
enum SyncStatusDefaultsKeys {
    static let lastSuccess = "sync_lastSuccess"
    static let pendingSince = "sync_pendingSince"
    static let lastFailure = "sync_lastFailure"
    static let lastFailureCode = "sync_lastFailureCode"
    static let lastErrorMessage = "sync_lastErrorMessage"
}

enum SyncFailureCode: Int {
    case none = 0
    case unknown = 1
    case quotaExceeded = 2

    var userMessage: String {
        switch self {
        case .none:
            return ""
        case .unknown:
            return "Cloud sync failed."
        case .quotaExceeded:
            return "iCloud storage is full (quota exceeded)."
        }
    }
}

final class CloudSyncMonitor: ObservableObject {
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    init(
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter

        observer = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
            event.type == .export,
            event.endDate != nil
        else {
            return
        }

        if let error = event.error {
            recordFailure(for: error)
            return
        }

        recordSuccess()
    }

    private func recordSuccess() {
        userDefaults.set(Date().timeIntervalSince1970, forKey: SyncStatusDefaultsKeys.lastSuccess)
        userDefaults.set(0, forKey: SyncStatusDefaultsKeys.lastFailure)
        userDefaults.set(SyncFailureCode.none.rawValue, forKey: SyncStatusDefaultsKeys.lastFailureCode)
        userDefaults.set("", forKey: SyncStatusDefaultsKeys.lastErrorMessage)
    }

    private func recordFailure(for error: Error) {
        let code: SyncFailureCode = containsQuotaExceeded(in: error) ? .quotaExceeded : .unknown
        let message = message(for: error, fallbackCode: code)

        userDefaults.set(Date().timeIntervalSince1970, forKey: SyncStatusDefaultsKeys.lastFailure)
        userDefaults.set(code.rawValue, forKey: SyncStatusDefaultsKeys.lastFailureCode)
        userDefaults.set(message, forKey: SyncStatusDefaultsKeys.lastErrorMessage)
    }

    private func message(for error: Error, fallbackCode: SyncFailureCode) -> String {
        let raw = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "The operation couldn't be completed." {
            return fallbackCode.userMessage
        }
        return raw
    }

    private func containsQuotaExceeded(in error: Error) -> Bool {
        if let cloudError = error as? CKError {
            if cloudError.code == .quotaExceeded {
                return true
            }

            if cloudError.code == .partialFailure {
                if let partials = cloudError.partialErrorsByItemID {
                    for nestedError in partials.values where containsQuotaExceeded(in: nestedError) {
                        return true
                    }
                }

                if let partials = cloudError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Any] {
                    for value in partials.values {
                        if let nestedError = value as? Error, containsQuotaExceeded(in: nestedError) {
                            return true
                        }
                    }
                }
            }
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           nsError.code == CKError.Code.quotaExceeded.rawValue {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           containsQuotaExceeded(in: underlying) {
            return true
        }

        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for nestedError in detailedErrors where containsQuotaExceeded(in: nestedError) {
                return true
            }
        }

        if let partials = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Any] {
            for value in partials.values {
                if let nestedError = value as? Error, containsQuotaExceeded(in: nestedError) {
                    return true
                }
            }
        }

        return false
    }
}
