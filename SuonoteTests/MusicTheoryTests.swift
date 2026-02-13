import XCTest
@testable import Suonote

/// Unit tests for ChordSuggestionEngine and MusicTheory (A-09)
final class MusicTheoryTests: XCTestCase {
    
    // MARK: - MusicTheory.noteIndex
    
    func testNoteIndexSharpNotes() {
        XCTAssertEqual(MusicTheory.noteIndex("C"), 0)
        XCTAssertEqual(MusicTheory.noteIndex("C#"), 1)
        XCTAssertEqual(MusicTheory.noteIndex("D"), 2)
        XCTAssertEqual(MusicTheory.noteIndex("E"), 4)
        XCTAssertEqual(MusicTheory.noteIndex("F"), 5)
        XCTAssertEqual(MusicTheory.noteIndex("B"), 11)
    }
    
    func testNoteIndexFlatNotes() {
        XCTAssertEqual(MusicTheory.noteIndex("Bb"), 10)
        XCTAssertEqual(MusicTheory.noteIndex("Eb"), 3)
        XCTAssertEqual(MusicTheory.noteIndex("Ab"), 8)
        XCTAssertEqual(MusicTheory.noteIndex("Db"), 1)
        XCTAssertEqual(MusicTheory.noteIndex("Gb"), 6)
    }
    
    func testNoteIndexInvalidReturnsNil() {
        XCTAssertNil(MusicTheory.noteIndex("X"))
        XCTAssertNil(MusicTheory.noteIndex(""))
    }
    
    // MARK: - Transpose
    
    func testTransposeUp() {
        XCTAssertEqual(ChordSuggestionEngine.transpose(note: "C", semitones: 7), "G")
        XCTAssertEqual(ChordSuggestionEngine.transpose(note: "G", semitones: 5), "C")
    }
    
    func testTransposeDown() {
        XCTAssertEqual(ChordSuggestionEngine.transpose(note: "C", semitones: -1), "B")
        XCTAssertEqual(ChordSuggestionEngine.transpose(note: "E", semitones: -4), "C")
    }
    
    func testTransposeWrapsAround() {
        XCTAssertEqual(ChordSuggestionEngine.transpose(note: "A", semitones: 12), "A")
        XCTAssertEqual(ChordSuggestionEngine.transpose(note: "A", semitones: -12), "A")
    }
    
    // MARK: - Interval Between
    
    func testIntervalBetween() {
        XCTAssertEqual(ChordSuggestionEngine.intervalBetween(from: "C", to: "G"), 7)
        XCTAssertEqual(ChordSuggestionEngine.intervalBetween(from: "C", to: "E"), 4)
        XCTAssertEqual(ChordSuggestionEngine.intervalBetween(from: "G", to: "C"), 5)
    }
    
    func testIntervalBetweenFlatKeys() {
        XCTAssertEqual(ChordSuggestionEngine.intervalBetween(from: "Bb", to: "F"), 7)
        XCTAssertEqual(ChordSuggestionEngine.intervalBetween(from: "Eb", to: "Bb"), 7)
    }
    
    // MARK: - Diatonic Chords
    
    func testDiatonicChordsMajor() {
        let chords = ChordSuggestionEngine.diatonicChords(forKey: "C", mode: .major)
        XCTAssertEqual(chords.count, 7)
        XCTAssertEqual(chords[0].root, "C")
        XCTAssertEqual(chords[0].quality, .major)
        XCTAssertEqual(chords[1].root, "D")
        XCTAssertEqual(chords[1].quality, .minor)
        XCTAssertEqual(chords[4].root, "G")
        XCTAssertEqual(chords[4].quality, .major)
        XCTAssertEqual(chords[6].quality, .diminished)
    }
    
    func testDiatonicChordsMinor() {
        let chords = ChordSuggestionEngine.diatonicChords(forKey: "A", mode: .minor)
        XCTAssertEqual(chords.count, 7)
        XCTAssertEqual(chords[0].root, "A")
        XCTAssertEqual(chords[0].quality, .minor)
        XCTAssertEqual(chords[2].quality, .major)  // III
    }
    
    func testDiatonicChordsDorian() {
        let chords = ChordSuggestionEngine.diatonicChords(forKey: "D", mode: .dorian)
        XCTAssertEqual(chords.count, 7)
        XCTAssertEqual(chords[0].quality, .minor)  // i
        XCTAssertEqual(chords[3].quality, .major)  // IV (characteristic of Dorian)
    }
    
    func testDiatonicChordsBbMajor() {
        let chords = ChordSuggestionEngine.diatonicChords(forKey: "Bb", mode: .major)
        XCTAssertEqual(chords.count, 7)
        XCTAssertEqual(chords[0].root, "A#") // Bb normalized to A#
        XCTAssertEqual(chords[0].quality, .major)
    }
    
    // MARK: - KeyMode
    
    func testKeyModeIntervals() {
        XCTAssertEqual(KeyMode.major.intervals.count, 7)
        XCTAssertEqual(KeyMode.pentatonicMajor.intervals.count, 5)
        XCTAssertEqual(KeyMode.blues.intervals.count, 6)
    }
    
    func testKeyModeIsMinor() {
        XCTAssertFalse(KeyMode.major.isMinor)
        XCTAssertTrue(KeyMode.minor.isMinor)
        XCTAssertTrue(KeyMode.dorian.isMinor)
        XCTAssertFalse(KeyMode.lydian.isMinor)
        XCTAssertTrue(KeyMode.blues.isMinor)
    }
    
    // MARK: - ChordQuality
    
    func testChordQualityIntervals() {
        XCTAssertEqual(ChordQuality.major.intervals, [0, 4, 7])
        XCTAssertEqual(ChordQuality.minor.intervals, [0, 3, 7])
        XCTAssertEqual(ChordQuality.dominant7.intervals, [0, 4, 7, 10])
        XCTAssertEqual(ChordQuality.power.intervals, [0, 7])
    }
    
    func testChordQualityIsMinor() {
        XCTAssertFalse(ChordQuality.major.isMinor)
        XCTAssertTrue(ChordQuality.minor.isMinor)
        XCTAssertTrue(ChordQuality.minor7.isMinor)
        XCTAssertTrue(ChordQuality.diminished.isMinor)
        XCTAssertFalse(ChordQuality.dominant7.isMinor)
    }
    
    // MARK: - Roman Numeral Analysis
    
    func testRomanNumeralMajorKey() {
        let roman = MusicTheoryUtils.romanNumeral(root: "G", quality: .major, keyRoot: "C", mode: .major)
        XCTAssertEqual(roman, "V")
    }
    
    func testRomanNumeralMinorChord() {
        let roman = MusicTheoryUtils.romanNumeral(root: "D", quality: .minor, keyRoot: "C", mode: .major)
        XCTAssertEqual(roman, "ii")
    }
    
    // MARK: - Nashville Numbers
    
    func testNashvilleNumber() {
        let num = MusicTheoryUtils.nashvilleNumber(root: "G", quality: .major, keyRoot: "C")
        XCTAssertEqual(num, "5")
    }
    
    // MARK: - Auto Key Detection
    
    func testAutoKeyDetection() {
        let chords: [(root: String, quality: ChordQuality)] = [
            ("C", .major), ("G", .major), ("A", .minor), ("F", .major)
        ]
        let result = MusicTheoryUtils.detectKey(chords: chords)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.root, "C")
        XCTAssertEqual(result?.mode, .major)
    }
    
    // MARK: - Voice Leading
    
    func testOptimalVoicingMinimizesMovement() {
        let voicing1 = ChordSuggestionEngine.optimalVoicing(root: "C", quality: .major, previousVoicing: nil)
        XCTAssertFalse(voicing1.isEmpty)
        
        let voicing2 = ChordSuggestionEngine.optimalVoicing(root: "F", quality: .major, previousVoicing: voicing1)
        XCTAssertFalse(voicing2.isEmpty)
        
        // F major voiced close to C major should have small total movement
        let totalMovement = zip(voicing1, voicing2).map { abs($0 - $1) }.reduce(0, +)
        XCTAssertLessThan(totalMovement, 20, "Voice leading should minimize movement")
    }
    
    // MARK: - Genre Suggestions
    
    func testGenreSuggestionsNotEmpty() {
        for genre in MusicGenre.allCases {
            let suggestions = genre.suggestions(keyRoot: "C")
            XCTAssertFalse(suggestions.isEmpty, "\(genre.rawValue) should have suggestions")
        }
    }
    
    // MARK: - Normalize
    
    func testNormalize() {
        XCTAssertEqual(MusicTheory.normalize("Bb"), "A#")
        XCTAssertEqual(MusicTheory.normalize("Eb"), "D#")
        XCTAssertEqual(MusicTheory.normalize("C"), "C")
        XCTAssertEqual(MusicTheory.normalize("F#"), "F#")
    }
    
    // MARK: - Project Validation
    
    func testProjectBPMClamped() {
        let project = Project(bpm: 500)
        XCTAssertEqual(project.bpm, 300)
        
        let project2 = Project(bpm: 5)
        XCTAssertEqual(project2.bpm, 20)
    }
    
    func testProjectTimeBottomValidated() {
        let project = Project(timeBottom: 3)
        XCTAssertEqual(project.timeBottom, 4) // Invalid, falls back to 4
    }
    
    func testProjectTagsDeduplicated() {
        let project = Project(tags: ["rock", "pop", "rock"])
        XCTAssertEqual(project.tags.count, 2)
    }
}
