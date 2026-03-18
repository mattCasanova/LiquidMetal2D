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

        // makeLookAt2D zeroes x/y translation (2D camera only translates z)
        XCTAssertEqual(mtx[3][0], 0, accuracy: epsilon)
        XCTAssertEqual(mtx[3][1], 0, accuracy: epsilon)
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
}
