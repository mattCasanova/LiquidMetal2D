import XCTest
@testable import LiquidMetal2D

/// Tests the world bounds calculation formula used by DefaultRenderer.
/// The formula: maxY = tan(fov/2) * (cameraDistance - zOrder), maxX = maxY * aspect
final class WorldBoundsTests: XCTestCase {

    /// Computes world bounds using the same formula as DefaultRenderer.getWorldBounds
    private func computeBounds(fov: Float, distance: Float, zOrder: Float, aspect: Float) -> WorldBounds {
        let angle = 0.5 * fov
        let maxY = tan(angle) * (distance - zOrder)
        let maxX = maxY * aspect
        return WorldBounds(minX: -maxX, maxX: maxX, minY: -maxY, maxY: maxY)
    }

    // MARK: - Hand-Computed Values

    func testDefaultSettings() {
        let fov = GameMath.degreeToRadian(90)
        let bounds = computeBounds(fov: fov, distance: 50, zOrder: 0, aspect: 2)

        // tan(pi/4) = 1.0, so maxY = 1.0 * 50 = 50, maxX = 50 * 2 = 100
        XCTAssertEqual(bounds.maxY, 50, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.minY, -50, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.maxX, 100, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.minX, -100, accuracy: GameMath.epsilon)
    }

    func testObjectCloserToCamera() {
        let fov = GameMath.degreeToRadian(90)
        let bounds = computeBounds(fov: fov, distance: 50, zOrder: -10, aspect: 2)

        // distance - zOrder = 50 - (-10) = 60
        XCTAssertEqual(bounds.maxY, 60, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.maxX, 120, accuracy: GameMath.epsilon)
    }

    func testObjectFartherFromCamera() {
        let fov = GameMath.degreeToRadian(90)
        let bounds = computeBounds(fov: fov, distance: 50, zOrder: 10, aspect: 2)

        // distance - zOrder = 50 - 10 = 40
        XCTAssertEqual(bounds.maxY, 40, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.maxX, 80, accuracy: GameMath.epsilon)
    }

    // MARK: - Symmetry

    func testBoundsAreSymmetric() {
        let fov = GameMath.degreeToRadian(60)
        let bounds = computeBounds(fov: fov, distance: 30, zOrder: 5, aspect: 1.5)

        XCTAssertEqual(bounds.maxX, -bounds.minX, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.maxY, -bounds.minY, accuracy: GameMath.epsilon)
    }

    // MARK: - Property Tests

    func testLargerFovGivesLargerBounds() {
        let narrow = computeBounds(fov: GameMath.degreeToRadian(45), distance: 50, zOrder: 0, aspect: 1)
        let wide = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)

        XCTAssertTrue(wide.maxY > narrow.maxY)
        XCTAssertTrue(wide.maxX > narrow.maxX)
    }

    func testGreaterDistanceGivesLargerBounds() {
        let near = computeBounds(fov: GameMath.degreeToRadian(90), distance: 20, zOrder: 0, aspect: 1)
        let far = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)

        XCTAssertTrue(far.maxY > near.maxY)
    }

    func testAspectOnlyAffectsX() {
        let square = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)
        let wide = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 2)

        XCTAssertEqual(square.maxY, wide.maxY, accuracy: GameMath.epsilon)
        XCTAssertTrue(wide.maxX > square.maxX)
    }

    func testUnitAspectGivesEqualXY() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)
        XCTAssertEqual(bounds.maxX, bounds.maxY, accuracy: GameMath.epsilon)
    }

    // MARK: - Edge Cases

    func testZOrderAtCameraCollapsesToZero() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 50, aspect: 1)
        XCTAssertEqual(bounds.maxY, 0, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.maxX, 0, accuracy: GameMath.epsilon)
    }

    func testVerySmallFov() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(1), distance: 50, zOrder: 0, aspect: 1)
        XCTAssertTrue(bounds.maxY < 1)
    }

    // MARK: - WorldBounds Utilities

    func testWidthAndHeight() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 2)
        XCTAssertEqual(bounds.width, 200, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.height, 100, accuracy: GameMath.epsilon)
    }

    func testCenter() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 2)
        XCTAssertEqual(bounds.center.x, 0, accuracy: GameMath.epsilon)
        XCTAssertEqual(bounds.center.y, 0, accuracy: GameMath.epsilon)
    }

    func testContainsOrigin() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)
        XCTAssertTrue(bounds.contains(Vec2(0, 0)))
    }

    func testContainsEdge() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)
        XCTAssertTrue(bounds.contains(Vec2(bounds.maxX, bounds.maxY)))
    }

    func testDoesNotContainOutside() {
        let bounds = computeBounds(fov: GameMath.degreeToRadian(90), distance: 50, zOrder: 0, aspect: 1)
        XCTAssertFalse(bounds.contains(Vec2(bounds.maxX + 1, 0)))
    }
}
