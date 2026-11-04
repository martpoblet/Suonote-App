import Foundation
import SwiftData

extension ModelContext {
    /// Saves the context and logs a failure instead of silently dropping it
    /// (`try? save()` hides errors such as a full disk or a schema problem).
    /// - Parameter what: Short description of the change, used in the log.
    /// - Returns: `true` when the save succeeded.
    @discardableResult
    func saveLogged(_ what: String = "") -> Bool {
        do {
            try save()
            return true
        } catch {
            let context = what.isEmpty ? "" : " (\(what))"
            AppLog.general.error("Save failed\(context): \(error.localizedDescription)")
            return false
        }
    }
}
