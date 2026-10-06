import Foundation
import LiquidMetal2D
@testable import MotionatorKit

/// The demo's stick figure: rig, clips and its one image.
enum Fixtures {
    static var repoRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }

    static var animations: URL { repoRoot.appendingPathComponent("Demo/LiquidMetal2D-Demo/Animations") }
    static var rigURL: URL { animations.appendingPathComponent("stickfigure.rig.json") }
    static var discURL: URL { repoRoot.appendingPathComponent("Demo/LiquidMetal2D-Demo/disc.png") }

    static func stickFigure() throws -> Character {
        try CharacterFiles.load(rigAt: rigURL, clips: CharacterFiles.clipURLs(besideRig: rigURL))
    }

    static func walk() throws -> AnimationClip {
        try AnimationFiles.loadClip(at: animations.appendingPathComponent("walk.clip.json"))
    }

    /// A fresh folder under the temporary directory.
    static func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MotionatorKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A two-bone rig: root (length 2) with a child (length 1) at its tip, one part each.
    static func twoBones() -> SkeletonDefinition {
        SkeletonDefinition(
            bones: [
                Bone(name: "upper", parent: nil, length: 2,
                     rest: RigidTransform2D(position: Vec2(1, 1), rotation: 0.3)),
                Bone(name: "lower", parent: 0, length: 1, rest: RigidTransform2D(position: Vec2(2, 0), rotation: 0.5)),
            ],
            attachments: [
                Attachment(name: "upperPart", bone: 0, size: Vec2(2, 0.5), offset: Vec2(1, 0)),
                Attachment(name: "lowerPart", bone: 1, size: Vec2(1, 0.5), offset: Vec2(0.5, 0), drawOrder: 1),
            ])
    }
}
