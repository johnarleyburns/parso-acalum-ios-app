@testable import Acalum
import XCTest

final class LocalStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        LocalStore.saveFavorites([])
        LocalStore.saveLastPrompt(nil)
        LocalStore.saveLastPillIDs([])
    }

    func testSaveAndLoadFavorites() {
        LocalStore.saveFavorites(["track_001", "track_002"])
        let loaded = LocalStore.loadFavorites()
        XCTAssertEqual(loaded, ["track_001", "track_002"])
    }

    func testSaveAndLoadPrompt() {
        LocalStore.saveLastPrompt("quiet guitar")
        XCTAssertEqual(LocalStore.loadLastPrompt(), "quiet guitar")
    }

    func testSaveAndLoadPillIDs() {
        LocalStore.saveLastPillIDs(["instrument:guitar", "mood:calm"])
        let loaded = LocalStore.loadLastPillIDs()
        XCTAssertEqual(loaded, ["instrument:guitar", "mood:calm"])
    }
}
