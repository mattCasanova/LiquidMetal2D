import XCTest
@testable import LiquidMetal2D

// MARK: - Helpers

@MainActor
private let standardBounds = WorldBounds(minX: -10, maxX: 10, minY: -10, maxY: 10)

@MainActor
private func makeObj(at position: Vec2, active: Bool = true) -> GameObj {
    let obj = GameObj()
    obj.position = position
    obj.isActive = active
    return obj
}

// MARK: - Init Tests

@MainActor
final class SpatialGridInitTests: XCTestCase {

    func testInitWithCellSize() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 5)
        XCTAssertEqual(grid.columns, 4) // 20 / 5
        XCTAssertEqual(grid.rows, 4)
        XCTAssertEqual(grid.cellWidth, 5)
        XCTAssertEqual(grid.cellHeight, 5)
    }

    func testInitWithRowsAndColumns() {
        let grid = SpatialGrid(bounds: standardBounds, columns: 4, rows: 2)
        XCTAssertEqual(grid.columns, 4)
        XCTAssertEqual(grid.rows, 2)
        XCTAssertEqual(grid.cellWidth, 5) // 20 / 4
        XCTAssertEqual(grid.cellHeight, 10) // 20 / 2
    }

    func testCellSizeRoundsUp() {
        // 20 / 7 = 2.857 → ceil = 3
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 7, cellHeight: 7)
        XCTAssertEqual(grid.columns, 3)
        XCTAssertEqual(grid.rows, 3)
    }

    func testCellSizeLargerThanBoundsProducesOneCell() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 100, cellHeight: 100)
        XCTAssertEqual(grid.columns, 1)
        XCTAssertEqual(grid.rows, 1)
    }

    func testExactDivision() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        XCTAssertEqual(grid.columns, 2)
        XCTAssertEqual(grid.rows, 2)
    }
}

// MARK: - Insert Tests

@MainActor
final class SpatialGridInsertTests: XCTestCase {

    func testInsertAndQueryFindsObject() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(5, 5))
        grid.insert(obj)

        let results = grid.query(near: Vec2(5, 5))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testInsertClampsOutOfBoundsLeft() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(-100, 0))
        grid.insert(obj)

        // Should be clamped to leftmost cell — query near left edge finds it
        let results = grid.query(near: Vec2(-10, 0))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testInsertClampsOutOfBoundsRight() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(100, 0))
        grid.insert(obj)

        let results = grid.query(near: Vec2(10, 0))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testInsertClampsOutOfBoundsAbove() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(0, 100))
        grid.insert(obj)

        let results = grid.query(near: Vec2(0, 10))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testInsertClampsOutOfBoundsBelow() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(0, -100))
        grid.insert(obj)

        let results = grid.query(near: Vec2(0, -10))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testInsertSkipsInactiveObjects() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(0, 0), active: false)
        grid.insert(obj)

        let results = grid.query(near: Vec2(0, 0))
        XCTAssertTrue(results.isEmpty)
    }

    func testInsertContentsOf() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let objs = [
            makeObj(at: Vec2(-5, -5)),
            makeObj(at: Vec2(5, 5)),
            makeObj(at: Vec2(0, 0)),
        ]
        grid.insert(contentsOf: objs)

        let results = grid.query(near: Vec2(0, 0))
        XCTAssertEqual(results.count, 3)
    }

    func testInsertContentsOfSkipsInactive() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 20, cellHeight: 20)
        let objs = [
            makeObj(at: Vec2(0, 0)),
            makeObj(at: Vec2(1, 1), active: false),
            makeObj(at: Vec2(2, 2)),
        ]
        grid.insert(contentsOf: objs)

        let results = grid.query(near: Vec2(0, 0))
        XCTAssertEqual(results.count, 2)
    }
}

// MARK: - Clear Tests

@MainActor
final class SpatialGridClearTests: XCTestCase {

    func testClearRemovesAllObjects() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        grid.insert(makeObj(at: Vec2(0, 0)))
        grid.insert(makeObj(at: Vec2(5, 5)))

        grid.clear()

        XCTAssertTrue(grid.query(near: Vec2(0, 0)).isEmpty)
        XCTAssertTrue(grid.query(near: Vec2(5, 5)).isEmpty)
        XCTAssertTrue(grid.potentialPairs().isEmpty)
    }

    func testClearAndReinsert() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(0, 0))
        grid.insert(obj)
        grid.clear()

        obj.position.set(5, 5)
        grid.insert(obj)

        let results = grid.query(near: Vec2(5, 5))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }
}

// MARK: - Potential Pairs Tests

@MainActor
final class SpatialGridPotentialPairsTests: XCTestCase {

    func testNoPairsWhenEmpty() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        XCTAssertTrue(grid.potentialPairs().isEmpty)
    }

    func testNoPairsWithSingleObject() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        grid.insert(makeObj(at: Vec2(0, 0)))
        XCTAssertTrue(grid.potentialPairs().isEmpty)
    }

    func testTwoObjectsSameCellProducesOnePair() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let a = makeObj(at: Vec2(1, 1))
        let b = makeObj(at: Vec2(2, 2))
        grid.insert(a)
        grid.insert(b)

        let pairs = grid.potentialPairs()
        XCTAssertEqual(pairs.count, 1)
        XCTAssertTrue(containsPair(pairs, a, b))
    }

    func testThreeObjectsSameCellProducesThreePairs() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 20, cellHeight: 20)
        let a = makeObj(at: Vec2(0, 0))
        let b = makeObj(at: Vec2(1, 0))
        let c = makeObj(at: Vec2(0, 1))
        grid.insert(a)
        grid.insert(b)
        grid.insert(c)

        let pairs = grid.potentialPairs()
        XCTAssertEqual(pairs.count, 3)
    }

    func testPairsInAdjacentCellsHorizontal() {
        // 4 columns: cells at x = [-10,-5), [-5,0), [0,5), [5,10)
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 20)
        let a = makeObj(at: Vec2(-3, 0))  // column 1
        let b = makeObj(at: Vec2(2, 0))   // column 2
        grid.insert(a)
        grid.insert(b)

        let pairs = grid.potentialPairs()
        XCTAssertEqual(pairs.count, 1)
        XCTAssertTrue(containsPair(pairs, a, b))
    }

    func testPairsInAdjacentCellsVertical() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 20, cellHeight: 5)
        let a = makeObj(at: Vec2(0, -3))  // row 1
        let b = makeObj(at: Vec2(0, 2))   // row 2
        grid.insert(a)
        grid.insert(b)

        let pairs = grid.potentialPairs()
        XCTAssertEqual(pairs.count, 1)
        XCTAssertTrue(containsPair(pairs, a, b))
    }

    func testPairsInDiagonalCells() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let a = makeObj(at: Vec2(-5, -5))  // top-left cell
        let b = makeObj(at: Vec2(5, 5))    // bottom-right cell
        grid.insert(a)
        grid.insert(b)

        let pairs = grid.potentialPairs()
        XCTAssertEqual(pairs.count, 1)
        XCTAssertTrue(containsPair(pairs, a, b))
    }

    func testNoPairsWhenTwoCellsApart() {
        // 4 columns of width 5
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 20)
        let a = makeObj(at: Vec2(-8, 0))  // column 0
        let b = makeObj(at: Vec2(7, 0))   // column 3
        grid.insert(a)
        grid.insert(b)

        let pairs = grid.potentialPairs()
        XCTAssertTrue(pairs.isEmpty)
    }

    func testNoDuplicatePairs() {
        // 2x2 grid, place objects in adjacent cells
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let a = makeObj(at: Vec2(-5, -5))
        let b = makeObj(at: Vec2(5, -5))
        let c = makeObj(at: Vec2(-5, 5))
        let d = makeObj(at: Vec2(5, 5))
        grid.insert(a)
        grid.insert(b)
        grid.insert(c)
        grid.insert(d)

        let pairs = grid.potentialPairs()
        // Verify no duplicate pairs using identity
        var seen = Set<String>()
        for (x, y) in pairs {
            let id1 = ObjectIdentifier(x)
            let id2 = ObjectIdentifier(y)
            let key = id1 < id2 ? "\(id1)-\(id2)" : "\(id2)-\(id1)"
            XCTAssertTrue(seen.insert(key).inserted, "Duplicate pair found")
        }
    }

    func testInactiveObjectsNotPaired() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 20, cellHeight: 20)
        let a = makeObj(at: Vec2(0, 0))
        let b = makeObj(at: Vec2(1, 1), active: false)
        grid.insert(a)
        grid.insert(b)

        XCTAssertTrue(grid.potentialPairs().isEmpty)
    }

    // MARK: - Helpers

    private func containsPair(
        _ pairs: [(GameObj, GameObj)],
        _ a: GameObj,
        _ b: GameObj
    ) -> Bool {
        return pairs.contains { ($0.0 === a && $0.1 === b) || ($0.0 === b && $0.1 === a) }
    }
}

// MARK: - Query Tests

@MainActor
final class SpatialGridQueryTests: XCTestCase {

    func testQueryReturnsObjectsInSameCell() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 10, cellHeight: 10)
        let obj = makeObj(at: Vec2(1, 1))
        grid.insert(obj)

        let results = grid.query(near: Vec2(2, 2))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testQueryReturnsObjectsInNeighborCells() {
        // 4x4 grid, obj in center-ish cell, query from adjacent cell
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 5)
        let obj = makeObj(at: Vec2(-3, -3))  // column 1, row 1
        grid.insert(obj)

        // Query from column 2, row 2 — obj should be in neighbor
        let results = grid.query(near: Vec2(2, 2))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testQueryDoesNotReturnDistantObjects() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 5)
        let obj = makeObj(at: Vec2(-8, -8))  // column 0, row 0
        grid.insert(obj)

        // Query from far corner
        let results = grid.query(near: Vec2(8, 8))
        XCTAssertFalse(results.contains(where: { $0 === obj }))
    }

    func testQueryCornerCellChecksValidNeighborsOnly() {
        // Place object in bottom-left corner cell
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 5)
        let obj = makeObj(at: Vec2(-9, -9))
        grid.insert(obj)

        // Query from same corner — should not crash, should find the object
        let results = grid.query(near: Vec2(-9, -9))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }

    func testQueryNearObjExcludesSelf() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 20, cellHeight: 20)
        let a = makeObj(at: Vec2(0, 0))
        let b = makeObj(at: Vec2(1, 1))
        grid.insert(a)
        grid.insert(b)

        let results = grid.query(near: a)
        XCTAssertFalse(results.contains(where: { $0 === a }))
        XCTAssertTrue(results.contains(where: { $0 === b }))
    }

    func testQueryClampsOutOfBoundsPosition() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 20, cellHeight: 20)
        let obj = makeObj(at: Vec2(0, 0))
        grid.insert(obj)

        // Query from way outside — clamped to edge, same single cell
        let results = grid.query(near: Vec2(100, 100))
        XCTAssertTrue(results.contains(where: { $0 === obj }))
    }
}

// MARK: - Integration Tests

@MainActor
final class SpatialGridIntegrationTests: XCTestCase {

    func testClearAndRebuildAcrossFrames() {
        // Use a finer grid so opposite corners aren't neighbors
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 5, cellHeight: 5)
        let obj = makeObj(at: Vec2(-8, -8))

        // Frame 1
        grid.insert(obj)
        XCTAssertEqual(grid.query(near: Vec2(-8, -8)).count, 1)

        // Frame 2: object moved to far corner
        grid.clear()
        obj.position.set(8, 8)
        grid.insert(obj)

        XCTAssertTrue(grid.query(near: Vec2(-8, -8)).isEmpty)
        XCTAssertEqual(grid.query(near: Vec2(8, 8)).count, 1)
    }

    func testLargeObjectCount() {
        let grid = SpatialGrid(bounds: standardBounds, cellWidth: 4, cellHeight: 4)
        var objects = [GameObj]()

        for _ in 0..<200 {
            let obj = makeObj(at: Vec2(
                Float.random(in: -10...10),
                Float.random(in: -10...10)))
            objects.append(obj)
        }

        grid.insert(contentsOf: objects)
        let pairs = grid.potentialPairs()

        // Should produce fewer pairs than O(n²) = 19,900
        // Exact count depends on distribution, but should be significantly less
        XCTAssertTrue(pairs.count < 200 * 199 / 2,
                      "Broadphase should reduce pairs vs O(n²)")
    }
}
