import XCTest
@testable import LiquidMetal2D

private let degree = GameMath.pi / 180

/// One bone of length 2 with a 2 × 0.5 box centred halfway along it.
private func makeOneBoneRig(restRotation: Float = 0, drawOrder: Int = 0,
                            textureName: String? = nil) -> SkeletonDefinition {
    SkeletonDefinition(
        bones: [Bone(name: "arm", parent: nil, length: 2, rest: RigidTransform2D(rotation: restRotation))],
        attachments: [Attachment(name: "arm", bone: 0, size: Vec2(2, 0.5), offset: Vec2(1, 0),
                                 textureName: textureName, drawOrder: drawOrder)])
}

private func makeRoot(at position: Vec2 = Vec2(10, 5), rotation: Float = 0) -> GameObj {
    let root = GameObj()
    root.position = position
    root.rotation = rotation
    return root
}

/// The four corners of a part as the shader draws it: scale, then rotate, then move.
private func corners(of part: GameObj) -> [Vec2] {
    [Vec2(-1, -1), Vec2(1, -1), Vec2(1, 1), Vec2(-1, 1)].map { unit in
        part.position + Vec2(unit.x * part.scale.x / 2, unit.y * part.scale.y / 2).rotated(by: part.rotation)
    }
}

final class SkeletonComponentTests: XCTestCase {

    private let epsilon: Float = 0.0001

    private func assertEqual(_ lhs: Vec2, _ rhs: Vec2, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: epsilon, "x", file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: epsilon, "y", file: file, line: line)
    }

    // MARK: - Placement

    func testPartSitsHalfwayAlongItsBone() throws {
        let root = makeRoot()
        let skeleton = try SkeletonComponent(parent: root, definition: makeOneBoneRig(), defaultTextureID: 0)
        let part = skeleton.parts[0]

        assertEqual(part.position, Vec2(11, 5))
        XCTAssertEqual(part.rotation, 0, accuracy: epsilon)
        assertEqual(part.scale, Vec2(2, 0.5))
    }

    func testScaleAndRootRotationMoveThePart() throws {
        let root = makeRoot(rotation: 90 * degree)
        let skeleton = try SkeletonComponent(parent: root, definition: makeOneBoneRig(), defaultTextureID: 0)
        skeleton.scale = 2
        skeleton.update(dt: 0)
        let part = skeleton.parts[0]

        assertEqual(part.position, Vec2(10, 7))
        XCTAssertEqual(part.rotation, 90 * degree, accuracy: epsilon)
        assertEqual(part.scale, Vec2(4, 1))
    }

    func testFlipMirrorsEveryCornerAboutTheRoot() throws {
        let root = makeRoot()
        let skeleton = try SkeletonComponent(
            parent: root, definition: makeOneBoneRig(restRotation: 30 * degree), defaultTextureID: 0)
        let unflipped = corners(of: skeleton.parts[0])

        skeleton.flipX = true
        skeleton.update(dt: 0)
        let flipped = corners(of: skeleton.parts[0])

        let mirrored = unflipped.map { Vec2(2 * root.position.x - $0.x, $0.y) }
        for corner in flipped {
            XCTAssertTrue(mirrored.contains { simd_distance($0, corner) < epsilon }, "\(corner) not in \(mirrored)")
        }
        for corner in mirrored {
            XCTAssertTrue(flipped.contains { simd_distance($0, corner) < epsilon }, "\(corner) not in \(flipped)")
        }
    }

    func testDrawOrderStepsZAndPartsFollowTheRootsActiveFlag() throws {
        let root = makeRoot()
        root.zOrder = 1
        let skeleton = try SkeletonComponent(
            parent: root, definition: makeOneBoneRig(drawOrder: 3), defaultTextureID: 0)

        XCTAssertEqual(skeleton.parts[0].zOrder, 1 + 3 * SkeletonComponent.zStep, accuracy: epsilon)
        XCTAssertTrue(skeleton.parts[0].isActive)

        root.isActive = false
        skeleton.update(dt: 0)
        XCTAssertFalse(skeleton.parts[0].isActive)
    }

    func testUpdateDrivesThePartsFromTheAnimation() throws {
        let root = makeRoot()
        let rig = makeOneBoneRig()
        let skeleton = try SkeletonComponent(parent: root, definition: rig, defaultTextureID: 0)
        let raise = try AnimationClip(
            name: "raise", duration: 1, loops: true,
            tracks: [BoneTrack(bone: "arm", rotation: [Keyframe(time: 0, value: 90 * degree)])]
        ).resolved(for: rig)

        skeleton.animator.play(raise)
        skeleton.update(dt: 0)

        assertEqual(skeleton.parts[0].position, Vec2(10, 6))
        XCTAssertEqual(skeleton.parts[0].rotation, 90 * degree, accuracy: epsilon)
    }

    func testWorldTransformOfBoneGivesTheTip() throws {
        let root = makeRoot()
        let rig = SkeletonDefinition(
            bones: [
                Bone(name: "upper", parent: nil, length: 2, rest: RigidTransform2D(rotation: 90 * degree)),
                Bone(name: "lower", parent: 0, length: 1,
                     rest: RigidTransform2D(position: Vec2(2, 0), rotation: -90 * degree)),
            ],
            attachments: [])
        let skeleton = try SkeletonComponent(parent: root, definition: rig, defaultTextureID: 0)
        skeleton.scale = 2
        skeleton.update(dt: 0)

        // Up 4 from the root to the elbow, then 2 to the right.
        let tip = skeleton.worldTransform(ofBone: 1).apply(to: Vec2(1 * skeleton.scale, 0))
        assertEqual(tip, Vec2(12, 9))

        skeleton.flipX = true
        let flippedTip = skeleton.worldTransform(ofBone: 1).apply(to: Vec2(1 * skeleton.scale, 0))
        assertEqual(flippedTip, Vec2(8, 9))
    }

    // MARK: - Visibility

    func testHiddenPartStopsDrawingButKeepsFollowingItsBone() throws {
        let root = makeRoot()
        let rig = makeOneBoneRig()
        let skeleton = try SkeletonComponent(parent: root, definition: rig, defaultTextureID: 0)
        let raise = try AnimationClip(
            name: "raise", duration: 1, loops: true,
            tracks: [BoneTrack(bone: "arm", rotation: [Keyframe(time: 0, value: 90 * degree)])]
        ).resolved(for: rig)

        try skeleton.setVisible(false, attachment: "arm")
        XCTAssertFalse(skeleton.parts[0].isActive)
        XCTAssertFalse(skeleton.isVisible(attachment: 0))

        skeleton.animator.play(raise)
        skeleton.update(dt: 0)
        XCTAssertFalse(skeleton.parts[0].isActive)
        assertEqual(skeleton.parts[0].position, Vec2(10, 6))

        try skeleton.setVisible(true, attachment: "arm")
        XCTAssertTrue(skeleton.parts[0].isActive)
    }

    func testVisiblePartStillHidesWithAnInactiveRoot() throws {
        let root = makeRoot()
        let skeleton = try SkeletonComponent(parent: root, definition: makeOneBoneRig(), defaultTextureID: 0)
        root.isActive = false

        skeleton.setVisible(true, attachment: 0)

        XCTAssertFalse(skeleton.parts[0].isActive)
    }

    func testUnknownAttachmentNameThrows() throws {
        let skeleton = try SkeletonComponent(parent: makeRoot(), definition: makeOneBoneRig(), defaultTextureID: 0)

        XCTAssertThrowsError(try skeleton.setVisible(false, attachment: "shield")) {
            XCTAssertEqual($0 as? SkeletonError, .unknownAttachment("shield"))
        }
    }

    func testDuplicateAttachmentNamesAreRejected() {
        var rig = makeOneBoneRig()
        rig.attachments.append(rig.attachments[0])

        XCTAssertThrowsError(try SkeletonComponent(parent: makeRoot(), definition: rig, defaultTextureID: 0)) {
            XCTAssertEqual($0 as? SkeletonError, .duplicateAttachmentName("arm"))
        }
    }

    // MARK: - Textures and validation

    func testTextureNamesResolveAndNilUsesTheDefault() throws {
        let root = makeRoot()
        let named = try SkeletonComponent(
            parent: root, definition: makeOneBoneRig(textureName: "sword"),
            defaultTextureID: 3, textureIDs: ["sword": 7])
        let plain = try SkeletonComponent(parent: root, definition: makeOneBoneRig(), defaultTextureID: 3)

        XCTAssertEqual(named.parts[0].get(AlphaBlendComponent.self)?.textureID, 7)
        XCTAssertEqual(plain.parts[0].get(AlphaBlendComponent.self)?.textureID, 3)
    }

    func testMissingTextureThrows() {
        XCTAssertThrowsError(try SkeletonComponent(
            parent: makeRoot(), definition: makeOneBoneRig(textureName: "sword"), defaultTextureID: 0)) {
            XCTAssertEqual($0 as? SkeletonError, .unknownTexture("sword"))
        }
    }

    func testInvalidRigThrows() {
        XCTAssertThrowsError(try SkeletonComponent(
            parent: makeRoot(), definition: SkeletonDefinition(bones: [], attachments: []), defaultTextureID: 0)) {
            XCTAssertEqual($0 as? SkeletonError, .noBones)
        }
    }

    func testPartsCarryTheAttachmentTintAndRegion() throws {
        var rig = makeOneBoneRig()
        rig.attachments[0].tint = Vec4(1, 0, 0, 1)
        rig.attachments[0].region = Vec4(0.5, 0.5, 0.25, 0)
        let skeleton = try SkeletonComponent(parent: makeRoot(), definition: rig, defaultTextureID: 0)
        let component = try XCTUnwrap(skeleton.parts[0].get(AlphaBlendComponent.self))

        XCTAssertEqual(component.tintColor, Vec4(1, 0, 0, 1))
        XCTAssertEqual(component.texTrans, Vec4(0.5, 0.5, 0.25, 0))
    }
}
