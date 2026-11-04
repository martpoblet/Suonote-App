import XCTest
@testable import Suonote

/// Tick math behind the MIDI export: chord positions are relative to their
/// section, delta times are relative to the previous event.
@MainActor
final class MIDIExportTests: XCTestCase {

    func testBackToBackChordsHaveNoGap() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        let first = clock.place(barIndex: 0, beatOffset: 0, duration: 4)
        let second = clock.place(barIndex: 1, beatOffset: 0, duration: 4)
        XCTAssertEqual(first.delta, 0)
        XCTAssertEqual(first.length, 1920)
        // Second chord starts exactly where the first one ends (bar 2 = tick 1920).
        XCTAssertEqual(second.delta, 0)
        XCTAssertEqual(clock.lastEventTick, 3840)
    }

    func testGapBetweenChordsIsRelativeToPreviousNoteOff() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        _ = clock.place(barIndex: 0, beatOffset: 0, duration: 1)       // 0...480
        let next = clock.place(barIndex: 0, beatOffset: 2, duration: 1) // starts at 960
        XCTAssertEqual(next.delta, 480)
    }

    func testFractionalBeatOffset() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        let chord = clock.place(barIndex: 0, beatOffset: 1.5, duration: 0.5)
        XCTAssertEqual(chord.delta, 720)
        XCTAssertEqual(chord.length, 240)
    }

    func testNextSectionStartsAtSectionBoundaryNotAtLastChordEnd() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        _ = clock.place(barIndex: 0, beatOffset: 0, duration: 1)   // ends at tick 480
        clock.finishSection(bars: 2)                                // section is 8 beats = 3840 ticks
        XCTAssertEqual(clock.sectionStartTick, 3840)
        let chord = clock.place(barIndex: 0, beatOffset: 0, duration: 4)
        XCTAssertEqual(chord.delta, 3840 - 480)
        XCTAssertEqual(clock.lastEventTick, 3840 + 1920)
    }

    func testChordsAfterFirstOneDoNotDriftInLaterSections() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        var absoluteStarts: [Double] = []
        var tick = 0.0
        for _ in 0..<3 {
            for bar in 0..<4 {
                let timing = clock.place(barIndex: bar, beatOffset: 0, duration: 4)
                tick += Double(timing.delta)
                absoluteStarts.append(tick)
                tick += Double(timing.length)
            }
            clock.finishSection(bars: 4)
        }
        let expected = (0..<12).map { Double($0) * 1920 }
        XCTAssertEqual(absoluteStarts, expected)
    }

    func testCompoundMeterUsesEighthNoteGrid() {
        var clock = MIDITickClock(timeTop: 6, timeBottom: 8)
        XCTAssertEqual(clock.ticksPerGridBeat, 240)
        let chord = clock.place(barIndex: 1, beatOffset: 0, duration: 6)
        XCTAssertEqual(chord.delta, 6 * 240)
        XCTAssertEqual(chord.length, 6 * 240)
    }

    func testOverlappingChordNeverProducesNegativeDelta() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        _ = clock.place(barIndex: 0, beatOffset: 0, duration: 4)
        let overlapping = clock.place(barIndex: 0, beatOffset: 1, duration: 1)
        XCTAssertEqual(overlapping.delta, 0)
    }

    func testEndOfTrackPadsToEndOfSong() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        _ = clock.place(barIndex: 0, beatOffset: 0, duration: 1)
        clock.finishSection(bars: 2)
        XCTAssertEqual(clock.endOfTrackDelta, 3840 - 480)
    }

    func testNegativeInputsAreClamped() {
        var clock = MIDITickClock(timeTop: 4, timeBottom: 4)
        let chord = clock.place(barIndex: -2, beatOffset: -1, duration: -3)
        XCTAssertEqual(chord.delta, 0)
        XCTAssertEqual(chord.length, 0)
        clock.finishSection(bars: -5)
        XCTAssertEqual(clock.sectionStartTick, 0)
    }

    func testFileNameStemRemovesPathCharacters() {
        XCTAssertEqual(ExportFileName.stem(for: "Love / Hate: Live"), "Love__Hate_Live")
        XCTAssertEqual(ExportFileName.stem(for: "///"), "Song")
        XCTAssertEqual(ExportFileName.stem(for: ""), "Song")
        XCTAssertLessThanOrEqual(ExportFileName.stem(for: String(repeating: "a", count: 300)).count, 80)
    }
}
