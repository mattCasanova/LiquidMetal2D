import XCTest
@testable import LiquidMetal2D

// MARK: - Perspective Projection Tests

final class PerspectiveProjectionTests: XCTestCase {

    private let epsilon: Float = 0.001

    func testMakePerspectiveNonZeroDiagonal() {
        let mtx = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.0, n: 0.1, f: 100)
        XCTAssertNotEqual(mtx[0][0], 0)
        XCTAssertNotEqual(mtx[1][1], 0)
        XCTAssertNotEqual(mtx[2][2], 0)
    }

    func testPerspectiveRoundTripOrigin() {
        let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.0, n: 0.1, f: 100)
        let view = Mat4.makeLookAt2D(Vec3(0, 0, 50))
        let vp = proj * view

        let worldPoint = Vec3(0, 0, 0)
        let projected = projectPoint(worldPoint, vp: vp)
        let unprojected = unprojectPoint(projected, vp: vp)

        XCTAssertEqual(unprojected.x, worldPoint.x, accuracy: epsilon)
        XCTAssertEqual(unprojected.y, worldPoint.y, accuracy: epsilon)
        XCTAssertEqual(unprojected.z, worldPoint.z, accuracy: epsilon)
    }

    func testPerspectiveRoundTripPositiveCoords() {
        let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.5, n: 0.1, f: 100)
        let view = Mat4.makeLookAt2D(Vec3(0, 0, 50))
        let vp = proj * view

        let worldPoint = Vec3(5, 3, 10)
        let projected = projectPoint(worldPoint, vp: vp)
        let unprojected = unprojectPoint(projected, vp: vp)

        XCTAssertEqual(unprojected.x, worldPoint.x, accuracy: epsilon)
        XCTAssertEqual(unprojected.y, worldPoint.y, accuracy: epsilon)
        XCTAssertEqual(unprojected.z, worldPoint.z, accuracy: epsilon)
    }

    func testPerspectiveRoundTripNegativeCoords() {
        let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.0, n: 0.1, f: 100)
        let view = Mat4.makeLookAt2D(Vec3(0, 0, 50))
        let vp = proj * view

        let worldPoint = Vec3(-7, -4, 5)
        let projected = projectPoint(worldPoint, vp: vp)
        let unprojected = unprojectPoint(projected, vp: vp)

        XCTAssertEqual(unprojected.x, worldPoint.x, accuracy: epsilon)
        XCTAssertEqual(unprojected.y, worldPoint.y, accuracy: epsilon)
        XCTAssertEqual(unprojected.z, worldPoint.z, accuracy: epsilon)
    }

    func testPerspectiveSymmetry() {
        let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.0, n: 0.1, f: 100)
        let view = Mat4.makeLookAt2D(Vec3(0, 0, 50))
        let vp = proj * view

        let p1 = projectPoint(Vec3(5, 3, 10), vp: vp)
        let p2 = projectPoint(Vec3(-5, -3, 10), vp: vp)

        XCTAssertEqual(p1.x, -p2.x, accuracy: epsilon)
        XCTAssertEqual(p1.y, -p2.y, accuracy: epsilon)
        XCTAssertEqual(p1.z, p2.z, accuracy: epsilon)
    }

    func testPerspectiveRoundTripNonDefaultCamera() {
        let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.0, n: 0.1, f: 100)
        let view = Mat4.makeLookAt2D(Vec3(10, 5, 30))
        let vp = proj * view

        let worldPoint = Vec3(12, 7, 5)
        let projected = projectPoint(worldPoint, vp: vp)
        let unprojected = unprojectPoint(projected, vp: vp)

        XCTAssertEqual(unprojected.x, worldPoint.x, accuracy: epsilon)
        XCTAssertEqual(unprojected.y, worldPoint.y, accuracy: epsilon)
        XCTAssertEqual(unprojected.z, worldPoint.z, accuracy: epsilon)
    }

    func testPerspectiveRoundTripDifferentZDepths() {
        let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 1.0, n: 0.1, f: 100)
        let view = Mat4.makeLookAt2D(Vec3(0, 0, 50))
        let vp = proj * view

        for z: Float in [0, 10, 20, 30, 40] {
            let worldPoint = Vec3(3, 2, z)
            let projected = projectPoint(worldPoint, vp: vp)
            let unprojected = unprojectPoint(projected, vp: vp)

            XCTAssertEqual(unprojected.x, worldPoint.x, accuracy: epsilon, "Failed at z=\(z)")
            XCTAssertEqual(unprojected.y, worldPoint.y, accuracy: epsilon, "Failed at z=\(z)")
            XCTAssertEqual(unprojected.z, worldPoint.z, accuracy: epsilon, "Failed at z=\(z)")
        }
    }

    // MARK: - Helpers

    private func projectPoint(_ world: Vec3, vp: Mat4) -> Vec3 {
        var clip = vp * world.to4D(1)
        clip.x /= clip.w
        clip.y /= clip.w
        clip.z /= clip.w
        return Vec3(clip.x, clip.y, clip.z)
    }

    private func unprojectPoint(_ ndc: Vec3, vp: Mat4) -> Vec3 {
        var point = vp.inverse * Vec4(ndc.x, ndc.y, ndc.z, 1)
        point.x /= point.w
        point.y /= point.w
        point.z /= point.w
        return Vec3(point.x, point.y, point.z)
    }
}

// MARK: - Orthographic Projection Tests

final class OrthographicProjectionTests: XCTestCase {

    private let epsilon: Float = 0.0001

    func testLeftMapsToNegativeOne() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let result = mtx * Vec4(-10, 0, 0, 1)
        XCTAssertEqual(result.x / result.w, -1, accuracy: epsilon)
    }

    func testRightMapsToPositiveOne() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let result = mtx * Vec4(10, 0, 0, 1)
        XCTAssertEqual(result.x / result.w, 1, accuracy: epsilon)
    }

    func testBottomMapsToNegativeOne() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let result = mtx * Vec4(0, -5, 0, 1)
        XCTAssertEqual(result.y / result.w, -1, accuracy: epsilon)
    }

    func testTopMapsToPositiveOne() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let result = mtx * Vec4(0, 5, 0, 1)
        XCTAssertEqual(result.y / result.w, 1, accuracy: epsilon)
    }

    func testNearZMapsToZero() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 1, farZ: 100)
        let result = mtx * Vec4(0, 0, -1, 1)
        XCTAssertEqual(result.z / result.w, 0, accuracy: epsilon)
    }

    func testFarZMapsToOne() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 1, farZ: 100)
        let result = mtx * Vec4(0, 0, -100, 1)
        XCTAssertEqual(result.z / result.w, 1, accuracy: epsilon)
    }

    func testCenterMapsToOrigin() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let result = mtx * Vec4(0, 0, 0, 1)
        XCTAssertEqual(result.x / result.w, 0, accuracy: epsilon)
        XCTAssertEqual(result.y / result.w, 0, accuracy: epsilon)
    }

    func testAsymmetricBoundsCenter() {
        let mtx = Mat4.makeOrthographic(left: 0, right: 20, bottom: 0, top: 10, nearZ: 0, farZ: 100)
        let center = mtx * Vec4(10, 5, 0, 1)
        XCTAssertEqual(center.x / center.w, 0, accuracy: epsilon)
        XCTAssertEqual(center.y / center.w, 0, accuracy: epsilon)
    }

    func testOrthographicRoundTrip() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let inv = mtx.inverse

        let original = Vec4(3, -2, -50, 1)
        let projected = mtx * original
        let recovered = inv * projected

        XCTAssertEqual(recovered.x / recovered.w, original.x, accuracy: epsilon)
        XCTAssertEqual(recovered.y / recovered.w, original.y, accuracy: epsilon)
        XCTAssertEqual(recovered.z / recovered.w, original.z, accuracy: epsilon)
    }

    func testOrthographicNoSizeChangeWithDepth() {
        let mtx = Mat4.makeOrthographic(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)

        let nearPoint = mtx * Vec4(5, 3, 0, 1)
        let farPoint = mtx * Vec4(5, 3, -50, 1)

        XCTAssertEqual(nearPoint.x / nearPoint.w, farPoint.x / farPoint.w, accuracy: epsilon)
        XCTAssertEqual(nearPoint.y / nearPoint.w, farPoint.y / farPoint.w, accuracy: epsilon)
    }
}

// MARK: - OrthographicProjection Class Tests

final class OrthographicProjectionClassTests: XCTestCase {

    func testSetStoresValues() {
        let proj = OrthographicProjection()
        proj.set(left: -5, right: 5, bottom: -3, top: 3, nearZ: 0.1, farZ: 50)

        XCTAssertEqual(proj.left, -5)
        XCTAssertEqual(proj.right, 5)
        XCTAssertEqual(proj.bottom, -3)
        XCTAssertEqual(proj.top, 3)
        XCTAssertEqual(proj.nearZ, 0.1)
        XCTAssertEqual(proj.farZ, 50)
    }

    func testMakeProducesValidMatrix() {
        let proj = OrthographicProjection()
        proj.set(left: -10, right: 10, bottom: -5, top: 5, nearZ: 0, farZ: 100)
        let mtx = proj.make()

        XCTAssertNotEqual(mtx[0][0], 0)
        XCTAssertNotEqual(mtx[1][1], 0)
        XCTAssertNotEqual(mtx[2][2], 0)
    }
}

// MARK: - Camera2D Tests

final class Camera2DTests: XCTestCase {

    private let epsilon: Float = 0.0001

    func testDefaultValues() {
        let cam = Camera2D()
        XCTAssertEqual(cam.eye.x, 0)
        XCTAssertEqual(cam.eye.y, 0)
        XCTAssertEqual(cam.distance, 0)
        XCTAssertEqual(cam.rotation, 0)
    }

    func testSetWithPoint() {
        let cam = Camera2D()
        cam.set(point: Vec3(5, 10, 30))
        XCTAssertEqual(cam.eye.x, 5)
        XCTAssertEqual(cam.eye.y, 10)
        XCTAssertEqual(cam.distance, 30)
    }

    func testSetWithComponents() {
        let cam = Camera2D()
        cam.set(x: 3, y: 7, distance: 25, rotation: 1.5)
        XCTAssertEqual(cam.eye.x, 3)
        XCTAssertEqual(cam.eye.y, 7)
        XCTAssertEqual(cam.distance, 25)
        XCTAssertEqual(cam.rotation, 1.5)
    }

    func testMakeNoRotationIsTranslation() {
        let cam = Camera2D()
        cam.set(point: Vec3(5, 10, 50))
        let mtx = cam.make()

        // The view matrix moves the world by -eye, so the camera pans in x/y as well as z
        XCTAssertEqual(mtx[3][0], -5, accuracy: epsilon)
        XCTAssertEqual(mtx[3][1], -10, accuracy: epsilon)
        XCTAssertEqual(mtx[3][2], -50, accuracy: epsilon)
    }

    func testMakeAtOriginIsIdentityLike() {
        let cam = Camera2D()
        cam.set(point: Vec3(0, 0, 0))
        let mtx = cam.make()

        // Should be identity-like (diagonal 1s, zero translation)
        XCTAssertEqual(mtx[0][0], 1, accuracy: epsilon)
        XCTAssertEqual(mtx[1][1], 1, accuracy: epsilon)
        XCTAssertEqual(mtx[2][2], 1, accuracy: epsilon)
        XCTAssertEqual(mtx[3][3], 1, accuracy: epsilon)
        XCTAssertEqual(mtx[3][0], 0, accuracy: epsilon)
        XCTAssertEqual(mtx[3][1], 0, accuracy: epsilon)
        XCTAssertEqual(mtx[3][2], 0, accuracy: epsilon)
    }

    func testMakeWithRotationDiffersFromWithout() {
        let cam1 = Camera2D()
        cam1.set(point: Vec3(0, 0, 50))

        let cam2 = Camera2D()
        cam2.set(x: 0, y: 0, distance: 50, rotation: GameMath.piOverTwo)

        let mtx1 = cam1.make()
        let mtx2 = cam2.make()

        // Matrices should differ when rotation is applied
        XCTAssertNotEqual(mtx1[0][0], mtx2[0][0])
    }

    func testMakeRotation360IsIdentityLike() {
        let cam = Camera2D()
        cam.set(x: 0, y: 0, distance: 50, rotation: GameMath.twoPi)
        let mtx = cam.make()

        // Full rotation should produce near-identity for the rotation part
        XCTAssertEqual(mtx[0][0], 1, accuracy: epsilon)
        XCTAssertEqual(mtx[0][1], 0, accuracy: epsilon)
        XCTAssertEqual(mtx[1][0], 0, accuracy: epsilon)
        XCTAssertEqual(mtx[1][1], 1, accuracy: epsilon)
    }

    func testRotationPivotsOnTheEye() {
        let cam = Camera2D()
        cam.set(x: 10, y: 5, distance: 50, rotation: 0.7)
        let viewSpaceEye = cam.make() * Vec4(10, 5, 0, 1)

        // The eye must land on the view axis whatever the rotation. If the matrix
        // order were swapped, the world would spin around (0, 0) and this would fail.
        XCTAssertEqual(viewSpaceEye.x, 0, accuracy: epsilon)
        XCTAssertEqual(viewSpaceEye.y, 0, accuracy: epsilon)
        XCTAssertEqual(viewSpaceEye.z, -50, accuracy: epsilon)
    }
}

// MARK: - Screen <-> World Tests

/// Exercises the real `Projection.project` / `Projection.unproject` with a
/// top-left-origin screen, the convention touches arrive in.
final class ScreenWorldProjectionTests: XCTestCase {

    private let epsilon: Float = 0.001
    private let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
    private let proj = Mat4.makePerspective(fovRadian: GameMath.piOverTwo, aspect: 800.0 / 600.0, n: 1, f: 100)

    private func makeView(x: Float = 0, y: Float = 0, rotation: Float = 0) -> Mat4 {
        let cam = Camera2D()
        cam.set(x: x, y: y, distance: 50, rotation: rotation)
        return cam.make()
    }

    private func project(_ world: Vec3, view: Mat4) -> Vec3 {
        Projection.project(
            worldPoint: world, projection: proj, viewMatrix: view, viewFrame: frame, viewBounds: frame)
    }

    /// Unprojects a screen point onto the world plane z = 0.
    private func unproject(screenX: Float, screenY: Float, view: Mat4) -> Vec3 {
        let depth = project(Vec3(0, 0, 0), view: view).z
        return Projection.unproject(
            screenPoint: Vec3(screenX, screenY, depth), projection: proj, viewMatrix: view,
            viewFrame: frame, viewBounds: frame)
    }

    func testScreenCentreUnprojectsToCameraAtOrigin() {
        let world = unproject(screenX: 400, screenY: 300, view: makeView())

        XCTAssertEqual(world.x, 0, accuracy: epsilon)
        XCTAssertEqual(world.y, 0, accuracy: epsilon)
    }

    func testScreenCentreUnprojectsToPannedCamera() {
        let world = unproject(screenX: 400, screenY: 300, view: makeView(x: 10, y: 5))

        XCTAssertEqual(world.x, 10, accuracy: epsilon)
        XCTAssertEqual(world.y, 5, accuracy: epsilon)
    }

    func testScreenCentreUnprojectsToPannedAndRotatedCamera() {
        let world = unproject(screenX: 400, screenY: 300, view: makeView(x: -4, y: 12, rotation: 0.7))

        XCTAssertEqual(world.x, -4, accuracy: epsilon)
        XCTAssertEqual(world.y, 12, accuracy: epsilon)
    }

    func testProjectPutsPannedAndRotatedCameraAtScreenCentre() {
        let screen = project(Vec3(-4, 12, 0), view: makeView(x: -4, y: 12, rotation: 0.7))

        XCTAssertEqual(screen.x, 400, accuracy: epsilon)
        XCTAssertEqual(screen.y, 300, accuracy: epsilon)
    }

    func testRotatedCameraTurnsTheWorldAroundTheEye() {
        // Camera turned 90° counter-clockwise, so the world appears turned 90° clockwise:
        // a point 5 units to the right of the eye shows up straight below screen centre.
        let screen = project(Vec3(15, 5, 0), view: makeView(x: 10, y: 5, rotation: GameMath.piOverTwo))

        XCTAssertEqual(screen.x, 400, accuracy: epsilon)
        XCTAssertGreaterThan(screen.y, 300 + 1)
    }

    func testHigherOnScreenIsLargerWorldY() {
        let view = makeView(x: 10, y: 5)
        let centre = unproject(screenX: 400, screenY: 300, view: view)
        let above = unproject(screenX: 400, screenY: 150, view: view)

        XCTAssertGreaterThan(above.y, centre.y)
    }

    func testRightOnScreenIsLargerWorldX() {
        let view = makeView(x: 10, y: 5)
        let centre = unproject(screenX: 400, screenY: 300, view: view)
        let right = unproject(screenX: 600, screenY: 300, view: view)

        XCTAssertGreaterThan(right.x, centre.x)
    }

    func testProjectPutsCameraPositionAtScreenCentre() {
        let screen = project(Vec3(10, 5, 0), view: makeView(x: 10, y: 5))

        XCTAssertEqual(screen.x, 400, accuracy: epsilon)
        XCTAssertEqual(screen.y, 300, accuracy: epsilon)
    }

    func testProjectPutsHigherWorldYNearerScreenTop() {
        let view = makeView()
        let low = project(Vec3(0, 0, 0), view: view)
        let high = project(Vec3(0, 7, 0), view: view)

        XCTAssertLessThan(high.y, low.y)
    }

    func testRoundTripCameraAtOrigin() {
        assertRoundTrip(view: makeView())
    }

    func testRoundTripPannedCamera() {
        assertRoundTrip(view: makeView(x: 10, y: 5))
    }

    func testRoundTripPannedAndRotatedCamera() {
        assertRoundTrip(view: makeView(x: -4, y: 12, rotation: 0.7))
    }

    private func assertRoundTrip(view: Mat4, file: StaticString = #filePath, line: UInt = #line) {
        for point in [Vec3(3, 7, 0), Vec3(-8, 2, 0), Vec3(0, -11, 0), Vec3(6, -3, 4)] {
            let screen = project(point, view: view)
            let world = Projection.unproject(
                screenPoint: screen, projection: proj, viewMatrix: view, viewFrame: frame, viewBounds: frame)

            XCTAssertEqual(world.x, point.x, accuracy: epsilon, "x of \(point)", file: file, line: line)
            XCTAssertEqual(world.y, point.y, accuracy: epsilon, "y of \(point)", file: file, line: line)
            XCTAssertEqual(world.z, point.z, accuracy: epsilon, "z of \(point)", file: file, line: line)
        }
    }

    func testUnprojectRayHitsCameraPositionAtScreenCentre() {
        let ray = Projection.unprojectRay(
            screenPoint: Vec2(400, 300), projection: proj, viewMatrix: makeView(x: 10, y: 5),
            viewFrame: frame, viewBounds: frame)

        XCTAssertEqual(ray.origin.x, 10, accuracy: epsilon)
        XCTAssertEqual(ray.origin.y, 5, accuracy: epsilon)
    }

    // MARK: - Visible bounds

    func testVisibleBoundsCentredOnOriginCamera() {
        let bounds = Projection.visibleBounds(
            eye: Vec2(0, 0), cameraDistance: 50, fov: GameMath.piOverTwo, aspect: 2, zOrder: 0)

        XCTAssertEqual(bounds.center.x, 0, accuracy: epsilon)
        XCTAssertEqual(bounds.center.y, 0, accuracy: epsilon)
        XCTAssertEqual(bounds.height, 100, accuracy: epsilon)
        XCTAssertEqual(bounds.width, 200, accuracy: epsilon)
    }

    func testVisibleBoundsFollowPannedCamera() {
        let bounds = Projection.visibleBounds(
            eye: Vec2(10, 5), cameraDistance: 50, fov: GameMath.piOverTwo, aspect: 2, zOrder: 0)

        XCTAssertEqual(bounds.center.x, 10, accuracy: epsilon)
        XCTAssertEqual(bounds.center.y, 5, accuracy: epsilon)
        XCTAssertEqual(bounds.height, 100, accuracy: epsilon)
        XCTAssertEqual(bounds.width, 200, accuracy: epsilon)
    }

    func testVisibleBoundsMatchUnprojectedScreenCorners() {
        let view = makeView(x: 10, y: 5)
        let bounds = Projection.visibleBounds(
            eye: Vec2(10, 5), cameraDistance: 50, fov: GameMath.piOverTwo, aspect: 800.0 / 600.0, zOrder: 0)
        let topLeft = unproject(screenX: 0, screenY: 0, view: view)
        let bottomRight = unproject(screenX: 800, screenY: 600, view: view)

        XCTAssertEqual(topLeft.x, bounds.minX, accuracy: epsilon)
        XCTAssertEqual(topLeft.y, bounds.maxY, accuracy: epsilon)
        XCTAssertEqual(bottomRight.x, bounds.maxX, accuracy: epsilon)
        XCTAssertEqual(bottomRight.y, bounds.minY, accuracy: epsilon)
    }
}
