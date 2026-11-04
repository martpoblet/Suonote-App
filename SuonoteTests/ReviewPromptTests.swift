import XCTest
@testable import Suonote

/// The rating invitation must only appear after real use, and then stay away.
final class ReviewPromptTests: XCTestCase {
    private let keys = [
        "reviewPrompt.launchCount",
        "reviewPrompt.lastAskedDate",
        "reviewPrompt.lastAskedVersion"
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    private func launch(_ times: Int) {
        for _ in 0..<times { ReviewPrompt.recordLaunch() }
    }

    func testDoesNotAskBeforeEnoughLaunches() {
        launch(ReviewPrompt.minimumLaunches - 1)
        XCTAssertFalse(ReviewPrompt.shouldAsk(songCount: 10, appVersion: "2.0.1"))
    }

    func testDoesNotAskWithTooFewSongs() {
        launch(ReviewPrompt.minimumLaunches)
        XCTAssertFalse(ReviewPrompt.shouldAsk(songCount: ReviewPrompt.minimumSongs - 1, appVersion: "2.0.1"))
    }

    func testAsksAfterRealUse() {
        launch(ReviewPrompt.minimumLaunches)
        XCTAssertTrue(ReviewPrompt.shouldAsk(songCount: ReviewPrompt.minimumSongs, appVersion: "2.0.1"))
    }

    func testStaysAwayAfterBeingAnswered() {
        launch(ReviewPrompt.minimumLaunches)
        let now = Date()
        ReviewPrompt.markAsked(now: now, appVersion: "2.0.1")

        XCTAssertFalse(ReviewPrompt.shouldAsk(songCount: 10, now: now, appVersion: "2.0.1"))
        // A new version alone is not enough: the cooldown still applies.
        XCTAssertFalse(ReviewPrompt.shouldAsk(songCount: 10, now: now.addingTimeInterval(86_400 * 30), appVersion: "2.1.0"))
    }

    func testCanAskAgainAfterCooldownOnANewVersion() {
        launch(ReviewPrompt.minimumLaunches)
        let now = Date()
        ReviewPrompt.markAsked(now: now, appVersion: "2.0.1")
        let later = now.addingTimeInterval(86_400 * Double(ReviewPrompt.cooldownDays + 1))

        XCTAssertFalse(ReviewPrompt.shouldAsk(songCount: 10, now: later, appVersion: "2.0.1"), "never twice for one version")
        XCTAssertTrue(ReviewPrompt.shouldAsk(songCount: 10, now: later, appVersion: "2.1.0"))
    }

    func testWriteReviewURLIsNilWithoutAnAppStoreID() {
        if ReviewPrompt.appStoreID == nil {
            XCTAssertNil(ReviewPrompt.writeReviewURL)
        } else {
            XCTAssertEqual(ReviewPrompt.writeReviewURL?.host, "apps.apple.com")
        }
    }
}
