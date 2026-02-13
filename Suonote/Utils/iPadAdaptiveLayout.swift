import SwiftUI

/// iPad-adaptive layout helpers (U-10)

// MARK: - Device Detection

enum DeviceType {
    case phone
    case pad
    
    static var current: DeviceType {
        UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
    }
}

// MARK: - Adaptive Grid Layout

struct AdaptiveGridLayout {
    /// Number of columns based on device and available width
    static func columns(for width: CGFloat) -> Int {
        switch width {
        case ..<400: return 2
        case 400..<700: return 3
        case 700..<1000: return 4
        default: return 5
        }
    }
    
    /// Chord palette columns
    static func chordColumns(for width: CGFloat) -> [GridItem] {
        let count = columns(for: width)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }
    
    /// Project list columns for iPad
    static func projectColumns(for width: CGFloat) -> [GridItem] {
        if width > 700 {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        }
        return [GridItem(.flexible())]
    }
}

// MARK: - Sidebar Layout for iPad

struct iPadSidebarWrapper<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail
    
    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        if DeviceType.current == .pad {
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
        } else {
            NavigationStack {
                detail
            }
        }
    }
}

// MARK: - Adaptive Spacing

extension CGFloat {
    /// Returns appropriate spacing for current device
    static var adaptiveSpacing: CGFloat {
        DeviceType.current == .pad ? 20 : 12
    }
    
    /// Returns appropriate padding for current device
    static var adaptivePadding: CGFloat {
        DeviceType.current == .pad ? 24 : 16
    }
}

// MARK: - Keyboard Shortcuts for iPad (with hardware keyboard)

struct iPadKeyboardShortcuts: ViewModifier {
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: () -> Void
    let onPlay: () -> Void
    
    func body(content: Content) -> some View {
        content
    }
}
