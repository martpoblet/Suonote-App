import XCTest
import SwiftData
@testable import Suonote

/// Take alignment (clicks heard by the mic) and repeating bars in Compose.
final class RecordingAndStructureTests: XCTestCase {

    // MARK: - Take alignment

    private let rate = 48_000.0

    /// Input as the mic hears it: room noise plus each click arriving
    /// `latency` seconds after it was rendered. `startSeconds` is the click
    /// clock time of sample 0.
    private func micInput(
        clickTimes: [Double],
        latency: Double,
        startSeconds: Double = -0.25,
        seconds: Double,
        noise: Float = 0.002,
        clickLevel: Float = 0.2
    ) -> [Float] {
        var generator = SystemRandomNumberGenerator()
        var samples = (0..<Int(seconds * rate)).map { _ in Float.random(in: -noise...noise, using: &generator) }
        for click in clickTimes {
            let start = Int(((click + latency - startSeconds) * rate).rounded())
            for offset in 0..<Int(0.03 * rate) where start + offset < samples.count {
                let t = Double(offset) / rate
                let envelope = Float(max(0, 1 - t / 0.03))
                samples[start + offset] += Float(sin(2 * .pi * 1_000 * t)) * envelope * clickLevel
            }
        }
        return samples
    }

    func testMeasuresSpeakerLatencyFromCountInClicks() throws {
        let beat = 0.5
        let clicks = (0..<4).map { Double($0) * beat }
        let input = micInput(clickTimes: clicks, latency: 0.037, seconds: 3)
        let latency = try XCTUnwrap(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
        XCTAssertEqual(latency, 0.037, accuracy: 0.001)
    }

    func testFastTempoStillFindsEachClick() throws {
        let beat = 60.0 / 200
        let clicks = (0..<8).map { Double($0) * beat }
        let input = micInput(clickTimes: clicks, latency: 0.012, seconds: 3.5)
        let latency = try XCTUnwrap(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
        XCTAssertEqual(latency, 0.012, accuracy: 0.001)
    }

    func testHeadphonesFallBackToReportedLatency() {
        // No bleed: the mic hears only the room.
        let beat = 0.5
        let clicks = (0..<4).map { Double($0) * beat }
        let input = micInput(clickTimes: [], latency: 0, seconds: 3)
        XCTAssertNil(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
    }

    func testInconsistentOnsetsAreRejected() {
        // Someone counting out loud at random times, not clicks.
        let beat = 0.5
        let clicks = (0..<4).map { Double($0) * beat }
        let hits = [0.05, 0.62, 1.21, 1.68]
        let input = micInput(clickTimes: hits, latency: 0, seconds: 3)
        XCTAssertNil(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
    }

    func testBeatClockCountsHeardBeats() {
        let start = mach_absolute_time()
        let clock = RecordBeatClock(startHostTime: start, beatSeconds: 0.5, beatsPerBar: 4, countInBeats: 4, outputLatency: 0.01)
        let later = start + AVAudioTimeHelper.hostTicks(seconds: 1.26)
        XCTAssertEqual(clock.heardBeats(atHostTime: later), 2.5, accuracy: 0.001)
        XCTAssertLessThan(clock.heardBeats(atHostTime: start), 0)
    }

    // MARK: - Repeating bars

    @MainActor
    private func makeSection(bars: Int, chords: [(bar: Int, root: String)]) throws -> (SectionTemplate, ModelContainer) {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let section = SectionTemplate(name: "Verse", bars: bars)
        ModelContext(container).insert(section)
        for chord in chords {
            section.chordEvents.append(ChordEvent(barIndex: chord.bar, beatOffset: 0, duration: 4, root: chord.root))
        }
        return (section, container)
    }

    @MainActor
    private func roots(_ section: SectionTemplate) -> [String] {
        (0..<section.bars).map { bar in
            section.chordEvents.first { $0.barIndex == bar }?.root ?? "-"
        }
    }

    @MainActor
    func testRepeatLastTwoBarsAppendsCopies() throws {
        let (section, container) = try makeSection(bars: 4, chords: [(0, "C"), (1, "G"), (2, "A"), (3, "F")])
        _ = container
        ComposeChordOps.repeatBars(in: section, range: 2..<4, times: 1)
        XCTAssertEqual(section.bars, 6)
        XCTAssertEqual(roots(section), ["C", "G", "A", "F", "A", "F"])
    }

    @MainActor
    func testRepeatBarSeveralTimesShiftsLaterBars() throws {
        let (section, container) = try makeSection(bars: 3, chords: [(0, "C"), (1, "G"), (2, "F")])
        _ = container
        ComposeChordOps.repeatBars(in: section, range: 0..<1, times: 2)
        XCTAssertEqual(roots(section), ["C", "C", "C", "G", "F"])
    }

    @MainActor
    func testRepeatKeepsBeatsAndDurationsAndEmptyBars() throws {
        let (section, container) = try makeSection(bars: 2, chords: [(0, "C")])
        _ = container
        section.chordEvents.append(ChordEvent(barIndex: 0, beatOffset: 2, duration: 2, root: "E", quality: .minor))
        ComposeChordOps.repeatBars(in: section, range: 0..<2, times: 1)
        XCTAssertEqual(section.bars, 4)
        let copied = section.chordEvents.filter { $0.barIndex == 2 }.sorted { $0.beatOffset < $1.beatOffset }
        XCTAssertEqual(copied.map(\.root), ["C", "E"])
        XCTAssertEqual(copied.last?.beatOffset, 2)
        XCTAssertEqual(copied.last?.duration, 2)
        XCTAssertEqual(copied.last?.quality, .minor)
        XCTAssertTrue(section.chordEvents.filter { $0.barIndex == 3 }.isEmpty)
    }

    @MainActor
    func testRepeatNeverGrowsPastTheLimit() throws {
        let (section, container) = try makeSection(bars: 40, chords: [])
        _ = container
        ComposeChordOps.repeatBars(in: section, range: 0..<40, times: 1)
        XCTAssertEqual(section.bars, 40)
        XCTAssertFalse(ComposeChordOps.canAdd(40, to: section))
        XCTAssertTrue(ComposeChordOps.canAdd(24, to: section))
    }

    @MainActor
    func testRepeatOptionsFitTheSection() throws {
        let (eight, container) = try makeSection(bars: 8, chords: [])
        _ = container
        XCTAssertEqual(ComposeRepeatOption.endings(of: eight).map(\.range), [7..<8, 6..<8, 4..<8, 0..<8])
        let (two, other) = try makeSection(bars: 2, chords: [])
        _ = other
        XCTAssertEqual(ComposeRepeatOption.endings(of: two).map(\.range), [1..<2, 0..<2])
    }
}

private enum AVAudioTimeHelper {
    static func hostTicks(seconds: Double) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return UInt64(seconds * 1_000_000_000 * Double(info.denom) / Double(info.numer))
    }
}
