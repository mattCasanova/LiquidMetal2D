import XCTest
@testable import LiquidMetal2D

final class CodableBlobStoreTests: XCTestCase {

    private struct Player: Codable, Equatable {
        let name: String
        let hp: Int
    }

    func testPutGetRoundTrip() throws {
        let store = CodableBlobStore<Player>(store: InMemoryBlobStore())
        let player = Player(name: "Matt", hp: 100)
        try store.put(player, key: "slot1")
        XCTAssertEqual(try store.get(key: "slot1"), player)
    }

    func testListAndDeletePassThroughToBackingStore() throws {
        let store = CodableBlobStore<Player>(store: InMemoryBlobStore())
        try store.put(Player(name: "A", hp: 1), key: "a")
        try store.put(Player(name: "B", hp: 2), key: "b")
        XCTAssertEqual(Set(try store.list()), Set(["a", "b"]))
        try store.delete(key: "a")
        XCTAssertEqual(try store.list(), ["b"])
    }

    func testGetWithMalformedDataThrowsDecodingError() throws {
        let backing = InMemoryBlobStore()
        try backing.put(Data("not even close to json".utf8), key: "bad")

        let store = CodableBlobStore<Player>(store: backing)
        XCTAssertThrowsError(try store.get(key: "bad")) { error in
            XCTAssertTrue(
                error is DecodingError,
                "expected DecodingError, got \(type(of: error))")
        }
    }

    func testGetMissingKeyPropagatesStoreError() {
        let store = CodableBlobStore<Player>(store: InMemoryBlobStore())
        XCTAssertThrowsError(try store.get(key: "missing")) { error in
            XCTAssertEqual(
                error as? InMemoryBlobStore.KeyNotFoundError,
                InMemoryBlobStore.KeyNotFoundError(key: "missing"))
        }
    }
}
