import XCTest
@testable import LiquidMetal2D

final class InMemoryBlobStoreTests: XCTestCase {

    func testPutGetRoundTrip() throws {
        let store = InMemoryBlobStore()
        let data = Data("hello".utf8)
        try store.put(data, key: "greeting")
        XCTAssertEqual(try store.get(key: "greeting"), data)
    }

    func testPutOverwritesExisting() throws {
        let store = InMemoryBlobStore()
        try store.put(Data("v1".utf8), key: "k")
        try store.put(Data("v2".utf8), key: "k")
        XCTAssertEqual(try store.get(key: "k"), Data("v2".utf8))
    }

    func testGetMissingKeyThrows() {
        let store = InMemoryBlobStore()
        XCTAssertThrowsError(try store.get(key: "missing")) { error in
            XCTAssertEqual(
                error as? InMemoryBlobStore.KeyNotFoundError,
                InMemoryBlobStore.KeyNotFoundError(key: "missing"))
        }
    }

    func testList() throws {
        let store = InMemoryBlobStore()
        try store.put(Data(), key: "a")
        try store.put(Data(), key: "b")
        XCTAssertEqual(Set(try store.list()), Set(["a", "b"]))
    }

    func testDeleteRemovesKey() throws {
        let store = InMemoryBlobStore()
        try store.put(Data(), key: "k")
        try store.delete(key: "k")
        XCTAssertFalse(try store.list().contains("k"))
    }

    func testDeleteMissingKeyThrows() {
        let store = InMemoryBlobStore()
        XCTAssertThrowsError(try store.delete(key: "missing")) { error in
            XCTAssertEqual(
                error as? InMemoryBlobStore.KeyNotFoundError,
                InMemoryBlobStore.KeyNotFoundError(key: "missing"))
        }
    }
}
