import XCTest
import SwiftData
@testable import Suonote

/// Regression tests for the November 2026 audit: pentatonic/blues crash, chord suggestions
/// for 7th chords, key-signature spelling and transposition.
final class TheoryFixesTests: XCTestCase {

    private func chord(_ root: String, _ quality: ChordQuality = .major) -> ChordEvent {
        ChordEvent(barIndex: 0, beatOffset: 0, duration: 4, root: root, quality: quality)
    }

    // MARK: - Pentatonic / blues must never crash the suggestion engine

    func testSuggestionsDoNotCrashForAnyMode() {
        for mode in KeyMode.allCases {
            let opening = ChordSuggestionEngine.suggestNextChord(after: nil, inKey: "C", mode: mode)
            XCTAssertFalse(opening.isEmpty, "No opening suggestions for \(mode)")

            let afterTonic = ChordSuggestionEngine.suggestNextChord(
                after: chord("C", mode.isMinor ? .minor : .major), inKey: "C", mode: mode
            )
            XCTAssertFalse(afterTonic.isEmpty, "No suggestions after the tonic for \(mode)")

            let contextual = ChordSuggestionEngine.suggestContextualChords(
                previousChords: [chord("C"), chord("G")],
                nextChords: [chord("A", .minor)],
                inKey: "C",
                mode: mode
            )
            XCTAssertFalse(contextual.isEmpty, "No contextual suggestions for \(mode)")

            _ = ChordSuggestionEngine.popularProgressions(forKey: "C", mode: mode)
        }
    }

    func testSuggestionModeMapsPentatonicsToParentScales() {
        XCTAssertEqual(ChordSuggestionEngine.suggestionMode(for: .pentatonicMajor), .major)
        XCTAssertEqual(ChordSuggestionEngine.suggestionMode(for: .pentatonicMinor), .minor)
        XCTAssertEqual(ChordSuggestionEngine.suggestionMode(for: .blues), .minor)
        XCTAssertEqual(ChordSuggestionEngine.suggestionMode(for: .dorian), .dorian)
    }

    // MARK: - Suggestions understand 7th chords and enharmonics

    func testDominantSeventhIsRecognisedAsV() {
        let suggestions = ChordSuggestionEngine.suggestNextChord(after: chord("G", .dominant7), inKey: "C", mode: .major)
        XCTAssertEqual(suggestions.first?.root, "C", "G7 in C major should resolve to I")
    }

    func testFlatRootedChordIsMatchedByPitchClass() {
        // Db == C#; in C#/Db major that is the tonic, so the first follow-up is the IV chord (F#).
        let suggestions = ChordSuggestionEngine.suggestNextChord(after: chord("Db"), inKey: "C#", mode: .major)
        XCTAssertEqual(suggestions.first?.root, "F#")
    }

    func testContextualSuggestionsAreSortedAndDeterministic() {
        let prev = [chord("C"), chord("F")]
        let a = ChordSuggestionEngine.suggestContextualChords(previousChords: prev, nextChords: [], inKey: "C", mode: .major)
        let b = ChordSuggestionEngine.suggestContextualChords(previousChords: prev, nextChords: [], inKey: "C", mode: .major)
        XCTAssertEqual(a.map(\.display), b.map(\.display))
        XCTAssertEqual(a.map(\.confidence), a.map(\.confidence).sorted(by: >))
    }

    // MARK: - Key-signature spelling

    func testFlatKeysSpellWithFlats() {
        XCTAssertEqual(MusicTheory.displayName(for: "A#", inKey: "A#", mode: .major), "Bb")
        XCTAssertEqual(MusicTheory.displayName(for: "D#", inKey: "A#", mode: .major), "Eb")
        XCTAssertEqual(MusicTheory.displayName(for: "G#", inKey: "G#", mode: .major), "Ab")
        XCTAssertEqual(MusicTheory.displayName(for: "A#", inKey: "D", mode: .minor), "Bb")   // D minor = 1 flat
        XCTAssertEqual(MusicTheory.displayName(for: "A#", inKey: "G", mode: .dorian), "Bb") // G dorian = F major signature
    }

    func testSharpKeysKeepSharps() {
        XCTAssertEqual(MusicTheory.displayName(for: "F#", inKey: "D", mode: .major), "F#")
        XCTAssertEqual(MusicTheory.displayName(for: "D#", inKey: "E", mode: .major), "D#")
        XCTAssertEqual(MusicTheory.displayName(for: "G#", inKey: "A", mode: .major), "G#")
    }

    func testBorrowedChordsInNaturalKeysUseFlats() {
        XCTAssertEqual(MusicTheory.displayName(for: "A#", inKey: "C", mode: .major), "Bb")
        XCTAssertEqual(MusicTheory.displayName(for: "G#", inKey: "C", mode: .major), "Ab")
        XCTAssertEqual(MusicTheory.displayName(for: "F#", inKey: "C", mode: .major), "F#")
    }

    // MARK: - Roman numerals / Nashville

    func testRomanNumeralForPentatonicUsesParentScale() {
        XCTAssertEqual(MusicTheoryUtils.romanNumeral(root: "G", quality: .major, keyRoot: "C", mode: .pentatonicMajor), "V")
        XCTAssertEqual(MusicTheoryUtils.romanNumeral(root: "A", quality: .minor, keyRoot: "C", mode: .pentatonicMajor), "vi")
    }

    func testRomanNumeralExtendedQualities() {
        XCTAssertEqual(MusicTheoryUtils.romanNumeral(root: "G", quality: .dominant9, keyRoot: "C", mode: .major), "V9")
        XCTAssertEqual(MusicTheoryUtils.romanNumeral(root: "C", quality: .sixth, keyRoot: "C", mode: .major), "I6")
    }

    func testNashvilleMinorSeventhKeepsTheSeven() {
        XCTAssertEqual(MusicTheoryUtils.nashvilleNumber(root: "D", quality: .minor7, keyRoot: "C"), "2-7")
        XCTAssertEqual(MusicTheoryUtils.nashvilleNumber(root: "D#", quality: .minor, keyRoot: "C"), "♭3-")
    }

    // MARK: - Transposition keeps the persisted display text in sync

    @MainActor
    func testApplyKeyChangeRefreshesDisplayAndSectionKey() throws {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let project = Project(title: "T", status: .idea, tags: [], keyRoot: "C", keyMode: .major, bpm: 100, timeTop: 4, timeBottom: 4)
        context.insert(project)

        let section = SectionTemplate(name: "Verse", bars: 2)
        section.sectionKeyRoot = "G"
        project.sectionTemplates.append(section)
        let c = ChordEvent(barIndex: 0, beatOffset: 0, duration: 4, root: "C", quality: .minor7, slashRoot: "G")
        section.chordEvents.append(c)

        project.applyKeyChange(oldRoot: "C", newRoot: "D")

        XCTAssertEqual(c.root, "D")
        XCTAssertEqual(c.slashRoot, "A")
        XCTAssertEqual(c.display, "Dm7/A", "Persisted display must follow the transposed notes")
        XCTAssertEqual(section.sectionKeyRoot, "A", "Section key override must transpose with the song")
    }
}
