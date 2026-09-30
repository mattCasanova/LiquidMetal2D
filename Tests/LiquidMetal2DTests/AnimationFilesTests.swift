import XCTest
@testable import LiquidMetal2D

/// Rig and clip files: round trips, hand-written JSON5, fields left out, and the
/// exact key names (a file written today must still load after any refactor).
final class AnimationFilesTests: XCTestCase {

    private func data(_ text: String) -> Data { Data(text.utf8) }

    private func makeRig() -> SkeletonDefinition {
        SkeletonDefinition(
            bones: [
                Bone(name: "hips", parent: nil, length: 0, rest: RigidTransform2D()),
                Bone(name: "spine", parent: 0, length: 3, rest: RigidTransform2D(rotation: 1.5707964)),
                Bone(name: "arm", parent: 1, length: 1.6,
                     rest: RigidTransform2D(position: Vec2(2.7, 0), rotation: 3.1415927))
            ],
            attachments: [
                Attachment(name: "torso", bone: 1, size: Vec2(3, 0.5), offset: Vec2(1.5, 0)),
                Attachment(name: "arm", bone: 2, size: Vec2(1.6, 0.4), offset: Vec2(0.8, 0), rotation: 0.1,
                           textureName: "limbs", region: Vec4(0.5, 0.5, 0, 0.5), tint: Vec4(0.2, 0.4, 0.6, 1),
                           drawOrder: 3)
            ])
    }

    private func makeClip() -> AnimationClip {
        AnimationClip(
            name: "wave", duration: 1.2, loops: true,
            tracks: [
                BoneTrack(bone: "arm", rotation: [Keyframe(time: 0, value: 3.1, easing: .easeInOutSine),
                                                  Keyframe(time: 0.6, value: 2.2)]),
                BoneTrack(bone: "hips", position: [Keyframe(time: 0, value: Vec2(0, 0)),
                                                   Keyframe(time: 1.2, value: Vec2(0, 0.3), easing: .easeOutBack)])
            ],
            events: [AnimationEvent(time: 0.6, name: "peak")])
    }

    // MARK: - Round trip

    func testRigAndClipRoundTrip() throws {
        let rig = makeRig()
        let clip = makeClip()

        XCTAssertEqual(try AnimationFiles.rig(from: AnimationFiles.data(for: rig)), rig)
        XCTAssertEqual(try AnimationFiles.clip(from: AnimationFiles.data(for: clip)), clip)
    }

    /// Written files spell out defaults too, and sort their keys so they diff cleanly.
    func testWritingListsEveryFieldInKeyOrder() throws {
        let text = String(decoding: try AnimationFiles.data(for: makeRig()), as: UTF8.self)

        for key in ["\"drawOrder\"", "\"region\"", "\"tint\"", "\"rotation\"", "\"position\""] {
            XCTAssertTrue(text.contains(key), "missing \(key)")
        }
        let attachments = try XCTUnwrap(text.range(of: "\"attachments\""))
        let bones = try XCTUnwrap(text.range(of: "\"bones\""))
        XCTAssertLessThan(attachments.lowerBound, bones.lowerBound, "keys are sorted")
        XCTAssertTrue(text.contains("\n"), "pretty-printed")
    }

    // MARK: - Hand-written files

    func testJSON5CommentsTrailingCommasAndLeftOutFieldsLoad() throws {
        let rig = try AnimationFiles.rig(from: data("""
            // A one-bone rig, written by hand.
            {
              bones: [
                { name: "arm", length: 2, rest: {}, },  // no parent: a root; rest at zero
              ],
              attachments: [
                { name: "arm", bone: 0, size: [2, 0.5], offset: [1, 0], },
              ],
            }
            """))

        XCTAssertEqual(rig, SkeletonDefinition(
            bones: [Bone(name: "arm", parent: nil, length: 2, rest: .identity)],
            attachments: [Attachment(name: "arm", bone: 0, size: Vec2(2, 0.5), offset: Vec2(1, 0))]))
    }

    func testClipFieldsLeftOutTakeTheirDefaults() throws {
        let clip = try AnimationFiles.clip(from: data("""
            { name: "idle", duration: 1, loops: true,
              tracks: [ { bone: "arm", rotation: [ { time: 0, value: 0.5 } ] } ] }
            """))

        XCTAssertEqual(clip, AnimationClip(
            name: "idle", duration: 1, loops: true,
            tracks: [BoneTrack(bone: "arm", rotation: [Keyframe(time: 0, value: 0.5, easing: .linear)])],
            events: []))
    }

    // MARK: - The format, pinned

    /// Every key spelled out, as plain JSON. If a rename breaks this test, it
    /// breaks every rig and clip file already written.
    func testFilesInTodaysShapeKeepLoading() throws {
        let rig = try AnimationFiles.rig(from: data("""
            {
              "bones": [
                { "name": "root", "length": 1, "rest": { "position": [0, 0], "rotation": 0 } },
                { "name": "arm", "parent": 0, "length": 2, "rest": { "position": [1, 0], "rotation": 0.5 } }
              ],
              "attachments": [
                { "name": "arm", "bone": 1, "size": [2, 0.5], "offset": [1, 0], "rotation": 0.25,
                  "textureName": "limbs", "region": [0.5, 1, 0.5, 0], "tint": [1, 0, 0, 1], "drawOrder": 2 }
              ]
            }
            """))
        let clip = try AnimationFiles.clip(from: data("""
            {
              "name": "swing", "duration": 0.5, "loops": false,
              "tracks": [
                { "bone": "arm",
                  "rotation": [ { "time": 0, "value": 0.5, "easing": "easeOutQuad" } ],
                  "position": [ { "time": 0.25, "value": [1, 0.2], "easing": "linear" } ] }
              ],
              "events": [ { "time": 0.25, "name": "hit" } ]
            }
            """))

        XCTAssertEqual(rig, SkeletonDefinition(
            bones: [Bone(name: "root", parent: nil, length: 1, rest: .identity),
                    Bone(name: "arm", parent: 0, length: 2,
                         rest: RigidTransform2D(position: Vec2(1, 0), rotation: 0.5))],
            attachments: [Attachment(name: "arm", bone: 1, size: Vec2(2, 0.5), offset: Vec2(1, 0), rotation: 0.25,
                                     textureName: "limbs", region: Vec4(0.5, 1, 0.5, 0), tint: Vec4(1, 0, 0, 1),
                                     drawOrder: 2)]))
        XCTAssertEqual(clip, AnimationClip(
            name: "swing", duration: 0.5, loops: false,
            tracks: [BoneTrack(bone: "arm",
                               rotation: [Keyframe(time: 0, value: 0.5, easing: .easeOutQuad)],
                               position: [Keyframe(time: 0.25, value: Vec2(1, 0.2))])],
            events: [AnimationEvent(time: 0.25, name: "hit")]))
    }

    // MARK: - Bad files

    func testAChildBeforeItsParentDecodesButFailsValidation() {
        let file = data("""
            { "bones": [ { "name": "child", "parent": 1, "length": 1, "rest": {} },
                         { "name": "root", "length": 1, "rest": {} } ],
              "attachments": [] }
            """)

        XCTAssertNoThrow(try AnimationFiles.makeDecoder().decode(SkeletonDefinition.self, from: file))
        XCTAssertThrowsError(try AnimationFiles.rig(from: file)) { error in
            XCTAssertEqual(error as? SkeletonError, .parentNotBeforeChild(bone: "child"))
        }
    }

    func testAMissingRequiredFieldNamesTheKey() {
        let file = data("""
            { "bones": [ { "name": "arm", "length": 1, "rest": {} } ],
              "attachments": [ { "name": "arm", "bone": 0, "offset": [1, 0] } ] }
            """)

        XCTAssertThrowsError(try AnimationFiles.rig(from: file)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "size")
        }
    }

    func testAClipNamingABoneTheRigLacksFailsWhenResolved() throws {
        let clip = try AnimationFiles.clip(from: data("""
            { name: "wag", duration: 1, loops: true, tracks: [ { bone: "tail", rotation: [ { time: 0, value: 1 } ] } ] }
            """))

        XCTAssertThrowsError(try clip.resolved(for: makeRig())) { error in
            XCTAssertEqual(error as? SkeletonError, .unknownBone("tail"))
        }
    }

    // MARK: - Files on disk

    func testLoadsRigAndClipFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let rigURL = folder.appendingPathComponent("figure.rig.json")
        let clipURL = folder.appendingPathComponent("wave.clip.json")
        try AnimationFiles.data(for: makeRig()).write(to: rigURL)
        try AnimationFiles.data(for: makeClip()).write(to: clipURL)

        XCTAssertEqual(try AnimationFiles.loadRig(at: rigURL), makeRig())
        XCTAssertEqual(try AnimationFiles.loadClip(at: clipURL), makeClip())
        XCTAssertThrowsError(try AnimationFiles.loadRig(at: folder.appendingPathComponent("missing.rig.json")))
    }
}
