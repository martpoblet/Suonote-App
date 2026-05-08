import Foundation

/// Auto-mix template applied to a freshly-created instrument track. Sets
/// volume, pan, reverb send, and a couple of EQ defaults so every newly
/// generated track lands in a balanced mix without manual tweaking.
///
/// Tuned for the GeneralUser GS soundfont. Per-instrument values come from a
/// "tracking template" approach: drums + bass center and louder; piano nearly
/// centered with moderate reverb; guitars hard-panned; strings/woodwinds
/// orchestrated wider with more reverb send; synths slightly drier than pads.
/// Style modifiers nudge the template toward genre conventions (lo-fi softer,
/// EDM brighter and wetter, hip-hop drier, ambient very wet, etc.).
enum StudioMixDefaults {

    /// Apply the template for `instrument` to the track. Idempotent — calling
    /// twice with the same style yields the same values. Existing per-track
    /// effect parameters that aren't volume/pan/reverb are left untouched.
    static func apply(to track: StudioTrack, style: StudioStyle?) {
        let base = baseTemplate(for: track.instrument)
        let mod = styleModifier(for: style)

        track.volume = clamp(base.volume + mod.volumeDelta, lower: 0.05, upper: 1.0)
        track.pan = clamp(base.pan, lower: -1.0, upper: 1.0)

        // Reverb is now a send into a shared bus, so values are in 0–1 of
        // bus-send range. The engine multiplies by 0.6 internally to keep tails
        // tasteful even at "max" send.
        track.reverbEnabled = base.reverbEnabled
        track.reverbMix = clamp(base.reverbMix + mod.reverbMixDelta, lower: 0, upper: 1)

        // Light auto-EQ tilt depending on the family role. We only set the
        // gains; the user can disable EQ from the track row if they want to
        // hear the raw sample.
        if base.eqLowGain != 0 || base.eqMidGain != 0 || base.eqHighGain != 0 {
            track.eqEnabled = true
            track.eqLowGain = base.eqLowGain
            track.eqMidGain = base.eqMidGain
            track.eqHighGain = base.eqHighGain
        }
    }

    private struct Template {
        let volume: Float
        let pan: Float
        let reverbEnabled: Bool
        let reverbMix: Float
        let eqLowGain: Float
        let eqMidGain: Float
        let eqHighGain: Float
    }

    private struct StyleModifier {
        let volumeDelta: Float
        let reverbMixDelta: Float
    }

    private static func baseTemplate(for instrument: StudioInstrument) -> Template {
        switch instrument {
        case .piano:
            return Template(volume: 0.78, pan: 0.0, reverbEnabled: true, reverbMix: 0.30,
                            eqLowGain: 0, eqMidGain: 0, eqHighGain: 1.0)
        case .synth:
            return Template(volume: 0.70, pan: 0.10, reverbEnabled: true, reverbMix: 0.32,
                            eqLowGain: 0, eqMidGain: -1, eqHighGain: 1.5)
        case .guitar:
            return Template(volume: 0.72, pan: -0.25, reverbEnabled: true, reverbMix: 0.22,
                            eqLowGain: -1, eqMidGain: 1, eqHighGain: 0.5)
        case .bass:
            return Template(volume: 0.85, pan: 0.0, reverbEnabled: false, reverbMix: 0.0,
                            eqLowGain: 1.5, eqMidGain: 0, eqHighGain: -1)
        case .strings:
            return Template(volume: 0.65, pan: 0.15, reverbEnabled: true, reverbMix: 0.50,
                            eqLowGain: -1, eqMidGain: 0, eqHighGain: 1.5)
        case .brass:
            return Template(volume: 0.70, pan: -0.15, reverbEnabled: true, reverbMix: 0.32,
                            eqLowGain: 0, eqMidGain: 0.5, eqHighGain: 0)
        case .woodwinds:
            return Template(volume: 0.65, pan: 0.20, reverbEnabled: true, reverbMix: 0.40,
                            eqLowGain: -2, eqMidGain: 0, eqHighGain: 1.0)
        case .organ:
            return Template(volume: 0.70, pan: 0.0, reverbEnabled: true, reverbMix: 0.22,
                            eqLowGain: 0, eqMidGain: 0, eqHighGain: 0)
        case .mallets:
            return Template(volume: 0.62, pan: 0.30, reverbEnabled: true, reverbMix: 0.35,
                            eqLowGain: -2, eqMidGain: 0, eqHighGain: 2.0)
        case .drums:
            return Template(volume: 0.85, pan: 0.0, reverbEnabled: true, reverbMix: 0.12,
                            eqLowGain: 1.0, eqMidGain: 0, eqHighGain: 1.0)
        case .audio:
            return Template(volume: 0.80, pan: 0.0, reverbEnabled: false, reverbMix: 0.0,
                            eqLowGain: 0, eqMidGain: 0, eqHighGain: 0)
        }
    }

    private static func styleModifier(for style: StudioStyle?) -> StyleModifier {
        switch style ?? .pop {
        case .pop:     return StyleModifier(volumeDelta: 0.0,  reverbMixDelta: 0.0)
        case .rock:    return StyleModifier(volumeDelta: 0.02, reverbMixDelta: -0.05)
        case .lofi:    return StyleModifier(volumeDelta: -0.04, reverbMixDelta: 0.10)
        case .edm:     return StyleModifier(volumeDelta: 0.0,  reverbMixDelta: 0.05)
        case .jazz:    return StyleModifier(volumeDelta: -0.02, reverbMixDelta: 0.08)
        case .hiphop:  return StyleModifier(volumeDelta: 0.02, reverbMixDelta: -0.10)
        case .funk:    return StyleModifier(volumeDelta: 0.0,  reverbMixDelta: -0.05)
        case .ambient: return StyleModifier(volumeDelta: -0.05, reverbMixDelta: 0.20)
        }
    }

    private static func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
        max(lower, min(upper, value))
    }
}
