import XCTest
@testable import LiquidMetal2D

/// Draw ordering for the sorted shaders, checked without a Metal device.
@MainActor
final class DrawListTests: XCTestCase {

    private func makeObj(zOrder: Float, textureID: Int, active: Bool = true, textured: Bool = true) -> GameObj {
        let obj = GameObj()
        obj.zOrder = zOrder
        obj.isActive = active
        if textured {
            obj.add(AlphaBlendComponent(parent: obj, textureID: textureID))
        }
        return obj
    }

    private func order(_ list: DrawList<AlphaBlendComponent>) -> [(Float, Int)] {
        return list.pairs.map { ($0.0.zOrder, $0.1.textureID) }
    }

    func testSortsFarToNear() {
        // Larger zOrder is nearer the camera, so it must draw last.
        let objects = [
            makeObj(zOrder: 5, textureID: 0), makeObj(zOrder: -2, textureID: 0), makeObj(zOrder: 0, textureID: 0)
        ]
        var list = DrawList<AlphaBlendComponent>()

        list.rebuild(from: objects)

        XCTAssertEqual(order(list).map(\.0), [-2, 0, 5])
    }

    func testGroupsByTextureWithinAZLevel() {
        let objects = [
            makeObj(zOrder: 0, textureID: 3), makeObj(zOrder: 0, textureID: 1),
            makeObj(zOrder: 1, textureID: 0), makeObj(zOrder: 0, textureID: 2)
        ]
        var list = DrawList<AlphaBlendComponent>()

        list.rebuild(from: objects)

        XCTAssertEqual(order(list).map(\.1), [1, 2, 3, 0])
        XCTAssertEqual(order(list).map(\.0), [0, 0, 0, 1])
    }

    func testSkipsInactiveAndUntexturedObjects() {
        let objects = [
            makeObj(zOrder: 0, textureID: 0),
            makeObj(zOrder: 0, textureID: 1, active: false),
            makeObj(zOrder: 0, textureID: 2, textured: false)
        ]
        var list = DrawList<AlphaBlendComponent>()

        list.rebuild(from: objects)

        XCTAssertEqual(list.pairs.count, 1)
        XCTAssertEqual(list.pairs[0].1.textureID, 0)
    }

    func testRebuildReplacesLastFrame() {
        var list = DrawList<AlphaBlendComponent>()
        list.rebuild(from: [makeObj(zOrder: 0, textureID: 0), makeObj(zOrder: 0, textureID: 1)])
        XCTAssertEqual(list.pairs.count, 2)

        list.rebuild(from: [makeObj(zOrder: 0, textureID: 7)])

        XCTAssertEqual(list.pairs.count, 1)
        XCTAssertEqual(list.pairs[0].1.textureID, 7)
    }

    func testAlreadyOrderedInputKeepsItsOrder() {
        let objects = [
            makeObj(zOrder: 0, textureID: 1), makeObj(zOrder: 0, textureID: 1),
            makeObj(zOrder: 0, textureID: 2), makeObj(zOrder: 3, textureID: 0)
        ]
        var list = DrawList<AlphaBlendComponent>()

        list.rebuild(from: objects)

        XCTAssertTrue(zip(list.pairs, objects).allSatisfy { $0.0 === $1 })
    }

    func testOneOutOfOrderObjectStillSorts() {
        // Only the last pair is out of order: the "already sorted" check must see it.
        let objects = [
            makeObj(zOrder: 0, textureID: 0), makeObj(zOrder: 2, textureID: 0), makeObj(zOrder: 1, textureID: 0)
        ]
        var list = DrawList<AlphaBlendComponent>()

        list.rebuild(from: objects)

        XCTAssertEqual(order(list).map(\.0), [0, 1, 2])
    }

    func testClearDropsReferences() {
        var list = DrawList<AlphaBlendComponent>()
        weak var released: GameObj?
        do {
            let obj = makeObj(zOrder: 0, textureID: 0)
            released = obj
            list.rebuild(from: [obj])
            XCTAssertEqual(list.pairs.count, 1)
        }

        list.clear()

        XCTAssertTrue(list.pairs.isEmpty)
        XCTAssertNil(released, "cleared list still holds the object")
    }

    func testPicksUpOtherTexturedComponents() {
        let obj = GameObj()
        obj.add(ParticleEmitterComponent(parent: obj, maxParticles: 1, textureID: 4))
        var list = DrawList<ParticleEmitterComponent>()

        list.rebuild(from: [obj])

        XCTAssertEqual(list.pairs.count, 1)
        XCTAssertEqual(list.pairs[0].1.textureID, 4)
    }
}
