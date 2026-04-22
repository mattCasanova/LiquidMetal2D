import XCTest
@testable import LiquidMetal2D

final class FileBlobStoreTests: XCTestCase {

    private var subdirectory: String!

    override func setUp() {
        super.setUp()
        subdirectory = "liquidmetal2d-test-\(UUID().uuidString)"
    }

    override func tearDown() {
        // Remove the subdirectory so tests don't leave garbage in the
        // simulator's Documents dir across runs.
        if let docs = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false) {
            let dir = docs.appendingPathComponent(subdirectory)
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }

    func testRoundTrip() throws {
        let store = try FileBlobStore(subdirectory: subdirectory)
        let data = Data("roundtrip".utf8)
        try store.put(data, key: "saved.bin")
        XCTAssertEqual(try store.get(key: "saved.bin"), data)
    }

    func testListReflectsWrites() throws {
        let store = try FileBlobStore(subdirectory: subdirectory)
        try store.put(Data(), key: "a.bin")
        try store.put(Data(), key: "b.bin")
        XCTAssertEqual(Set(try store.list()), Set(["a.bin", "b.bin"]))
    }

    func testDeleteRemovesFile() throws {
        let store = try FileBlobStore(subdirectory: subdirectory)
        try store.put(Data(), key: "will-vanish.bin")
        try store.delete(key: "will-vanish.bin")
        XCTAssertFalse(try store.list().contains("will-vanish.bin"))
    }

    func testReopenSameSubdirectorySeesEarlierWrites() throws {
        let write = try FileBlobStore(subdirectory: subdirectory)
        try write.put(Data("persist".utf8), key: "persisted.bin")

        let read = try FileBlobStore(subdirectory: subdirectory)
        XCTAssertEqual(try read.get(key: "persisted.bin"), Data("persist".utf8))
    }
}
