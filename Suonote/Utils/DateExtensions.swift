import Foundation

extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)
        
        // Largest non-zero unit, formatted by Foundation so it localizes automatically
        // (e.g. "2 days ago" / "hace 2 días").
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        
        if let year = components.year, year > 0 {
            return formatter.localizedString(from: DateComponents(year: -year))
        }
        
        if let month = components.month, month > 0 {
            return formatter.localizedString(from: DateComponents(month: -month))
        }
        
        if let week = components.weekOfYear, week > 0 {
            return formatter.localizedString(from: DateComponents(weekOfMonth: -week))
        }
        
        if let day = components.day, day > 0 {
            return formatter.localizedString(from: DateComponents(day: -day))
        }
        
        if let hour = components.hour, hour > 0 {
            return formatter.localizedString(from: DateComponents(hour: -hour))
        }
        
        if let minute = components.minute, minute > 0 {
            return formatter.localizedString(from: DateComponents(minute: -minute))
        }
        
        return String(localized: "Just now")
    }
}
