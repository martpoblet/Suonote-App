import SwiftUI

// MARK: - Record area helpers
/// Shared formatting, persisted capture preferences and the bridge between a
/// `Recording`'s stored effect fields and `AudioEffectsProcessor.EffectSettings`.

enum RecordFormat {
    /// "1:05" — list durations.
    static func duration(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Whole seconds part for the big elapsed counter ("1:05").
    static func elapsedMain(_ time: TimeInterval) -> String {
        duration(time)
    }

    /// Tenths for the big elapsed counter (".4").
    static func elapsedTenths(_ time: TimeInterval) -> String {
        let tenths = Int((max(0, time) * 10).rounded(.down)) % 10
        return ".\(tenths)"
    }

    /// Spoken form for VoiceOver ("1 minute 5 seconds").
    static func spoken(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = time >= 60 ? [.minute, .second] : [.second]
        return formatter.string(from: max(0, time.rounded())) ?? duration(time)
    }
}

/// Capture preferences remembered between takes (so the record button can
/// start instantly with the last setup).
enum RecordPreferenceKey {
    static let countInBars = "record.countInBars"
    static let clickEnabled = "record.clickEnabled"
    static let lastType = "record.lastType"
}

// MARK: - Effects bridge

extension Recording {
    /// The take's stored effect chain as processor settings (read/write).
    var recordEffectSettings: AudioEffectsProcessor.EffectSettings {
        get {
            var s = AudioEffectsProcessor.EffectSettings()
            s.reverbEnabled = reverbEnabled
            s.reverbMix = reverbMix
            s.reverbSize = reverbSize
            s.delayEnabled = delayEnabled
            s.delayTime = delayTime
            s.delayFeedback = delayFeedback
            s.delayMix = delayMix
            s.eqEnabled = eqEnabled
            s.lowGain = lowGain
            s.midGain = midGain
            s.highGain = highGain
            s.compressionEnabled = compressionEnabled
            s.compressionThreshold = compressionThreshold
            s.compressionRatio = compressionRatio
            return s
        }
        set {
            reverbEnabled = newValue.reverbEnabled
            reverbMix = newValue.reverbMix
            reverbSize = newValue.reverbSize
            delayEnabled = newValue.delayEnabled
            delayTime = newValue.delayTime
            delayFeedback = newValue.delayFeedback
            delayMix = newValue.delayMix
            eqEnabled = newValue.eqEnabled
            lowGain = newValue.lowGain
            midGain = newValue.midGain
            highGain = newValue.highGain
            compressionEnabled = newValue.compressionEnabled
            compressionThreshold = newValue.compressionThreshold
            compressionRatio = newValue.compressionRatio
        }
    }

    /// Short names of the pedals that are switched on ("Reverb", "EQ"…).
    var recordActiveEffectNames: [String] {
        var names: [String] = []
        if reverbEnabled { names.append(String(localized: "Reverb")) }
        if delayEnabled { names.append(String(localized: "Delay")) }
        if eqEnabled { names.append(String(localized: "EQ")) }
        if compressionEnabled { names.append(String(localized: "Comp")) }
        return names
    }

    /// File URL if the audio is still on disk.
    var recordFileURL: URL? {
        FileManagerUtils.existingRecordingURL(for: fileName)
    }
}

extension RecordingType {
    /// Localized name for display. `rawValue` is persisted — never show it directly.
    var recordDisplayName: String {
        switch self {
        case .sketch: return String(localized: "Sketch")
        case .voice: return String(localized: "Voice")
        case .guitar: return String(localized: "Guitar")
        case .piano: return String(localized: "Piano")
        case .melody: return String(localized: "Melody Idea")
        case .beat: return String(localized: "Beat")
        case .other: return String(localized: "Other")
        }
    }
}

extension AudioEffectsProcessor.EffectSettings {
    var recordActiveCount: Int {
        [reverbEnabled, delayEnabled, eqEnabled, compressionEnabled].filter { $0 }.count
    }
}

// MARK: - Arrangement helpers

extension Project {
    /// Sections in arrangement order, each listed once.
    var recordUniqueSections: [SectionTemplate] {
        var seen = Set<UUID>()
        return arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { item in
                guard let section = item.sectionTemplate, seen.insert(section.id).inserted else { return nil }
                return section
            }
    }
}
