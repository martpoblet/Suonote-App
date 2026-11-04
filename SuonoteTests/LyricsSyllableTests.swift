import XCTest
import NaturalLanguage
@testable import Suonote

/// Spanish syllable counting (vowel nuclei, diphthongs/hiatus, silent u, no
/// silent-final-e rule) and the untouched English path.
@MainActor
final class LyricsSyllableTests: XCTestCase {

    private func es(_ word: String) -> Int {
        LyricsAnalysis.syllables(inWord: word, language: .spanish)
    }

    private func en(_ word: String) -> Int {
        LyricsAnalysis.syllables(inWord: word, language: .english)
    }

    // MARK: Spanish

    func testSpanishFinalEIsPronounced() {
        XCTAssertEqual(es("noche"), 2)
        XCTAssertEqual(es("tarde"), 2)
        XCTAssertEqual(es("siempre"), 2)
        XCTAssertEqual(es("madre"), 2)
    }

    func testSpanishHiatusWithAccentedWeakVowel() {
        XCTAssertEqual(es("país"), 2)
        XCTAssertEqual(es("mía"), 2)
        XCTAssertEqual(es("música"), 3)
    }

    func testSpanishDiphthongs() {
        XCTAssertEqual(es("canción"), 2)
        XCTAssertEqual(es("aire"), 2)
        XCTAssertEqual(es("quiero"), 2)
    }

    func testSpanishSilentUAfterQAndG() {
        XCTAssertEqual(es("guitarra"), 3)
        XCTAssertEqual(es("que"), 1)
        // "gü" keeps its u: pin-güi-no.
        XCTAssertEqual(es("pingüino"), 3)
    }

    func testSpanishAccentedStrongVowel() {
        XCTAssertEqual(es("corazón"), 3)
    }

    func testSpanishFinalYIsAVowel() {
        XCTAssertEqual(es("hoy"), 1)
        XCTAssertEqual(es("mayo"), 2)
    }

    func testSpanishLineSumsWords() {
        XCTAssertEqual(LyricsAnalysis.syllables(inLine: "la noche y el corazón", language: .spanish), 8)
    }

    // MARK: English (unchanged)

    func testEnglishSilentEStillApplies() {
        XCTAssertEqual(en("love"), 1)
        XCTAssertEqual(en("fire"), 1)
        XCTAssertEqual(en("little"), 2)
    }
}
