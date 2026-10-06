import XCTest
import Metal
import LiquidMetal2D
@testable import MotionatorKit

@MainActor
final class ContactSheetTests: XCTestCase {

    private func requireMetal() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("No Metal device on this host") }
    }

    func testFourFramesOfTheWalkDiffer() throws {
        try requireMetal()
        var sheet = ContactSheet()
        sheet.frames = 4
        sheet.cellSize = 64
        sheet.labels = false

        let image = try sheet.render(try Fixtures.stickFigure(), clip: "walk")

        XCTAssertEqual(image.width, 256)
        XCTAssertEqual(image.height, 64)
        let cells = (0..<4).map { Self.pixels(of: image, cell: $0, size: 64) }
        for (index, cell) in cells.enumerated() {
            XCTAssertTrue(cell.contains { $0 != cell[0] }, "cell \(index) has more than the background")
        }
        XCTAssertNotEqual(cells[0], cells[2], "the walk at 0 and at 0.5 differ")
    }

    func testLabelsAddAStripAndAMissingClipIsNamed() throws {
        try requireMetal()
        var sheet = ContactSheet()
        sheet.frames = 2
        sheet.cellSize = 32
        let image = try sheet.render(try Fixtures.stickFigure(), clip: "idle")
        XCTAssertEqual(image.height, 32 + ContactSheet.labelHeight)

        XCTAssertThrowsError(try sheet.render(try Fixtures.stickFigure(), clip: "moonwalk")) { error in
            XCTAssertEqual("\(error)", "no clip named moonwalk")
        }
    }

    func testSampleTimes() {
        XCTAssertEqual(ContactSheet.sampleTimes(duration: 1, loops: true, frames: 4), [0, 0.25, 0.5, 0.75])
        XCTAssertEqual(ContactSheet.sampleTimes(duration: 1, loops: false, frames: 3), [0, 0.5, 1])
        XCTAssertEqual(ContactSheet.sampleTimes(duration: 1, loops: false, frames: 1), [0])
    }

    static func pixels(of image: CGImage, cell: Int, size: Int) -> [UInt32] {
        var bytes = [UInt32](repeating: 0, count: size * size)
        let context = CGContext(
            data: &bytes, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image.cropping(to: CGRect(x: cell * size, y: 0, width: size, height: size))!,
                      in: CGRect(x: 0, y: 0, width: size, height: size))
        return bytes
    }
}
