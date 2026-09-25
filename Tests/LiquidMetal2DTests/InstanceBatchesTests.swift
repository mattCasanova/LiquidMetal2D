import XCTest
@testable import LiquidMetal2D

/// The per-frame texture runs the textured shaders draw from.
final class InstanceBatchesTests: XCTestCase {

    private typealias Batch = InstanceBatches.Batch

    private func instances(textures: [Int]) -> InstanceBatches {
        var instances = InstanceBatches()
        for texture in textures {
            instances.append(textureId: texture)
        }
        return instances
    }

    func testConsecutiveInstancesSharingATextureShareABatch() {
        let instances = instances(textures: [1, 1, 2, 2, 2, 1])

        XCTAssertEqual(instances.batches, [
            Batch(textureId: 1, startIndex: 0, count: 2),
            Batch(textureId: 2, startIndex: 2, count: 3),
            Batch(textureId: 1, startIndex: 5, count: 1)
        ])
        XCTAssertEqual(instances.count, 6)
    }

    func testNothingAppendedMeansNoBatches() {
        let instances = InstanceBatches()

        XCTAssertTrue(instances.batches.isEmpty)
        XCTAssertEqual(instances.count, 0)
    }

    func testResetStartsAFreshFrame() {
        var instances = instances(textures: [3, 3, 4])

        instances.reset()
        instances.append(textureId: 4)

        XCTAssertEqual(instances.batches, [Batch(textureId: 4, startIndex: 0, count: 1)])
        XCTAssertEqual(instances.count, 1)
    }

    func testInstancesAfterADrawTakeTheNextSlots() {
        // A shader switch mid-frame draws what's queued. Later instances must
        // not reuse the slots those draws read from.
        var instances = instances(textures: [7, 7])

        instances.removeDrawnBatches()
        instances.append(textureId: 7)

        XCTAssertEqual(instances.batches, [Batch(textureId: 7, startIndex: 2, count: 1)])
        XCTAssertEqual(instances.count, 3)
    }
}
