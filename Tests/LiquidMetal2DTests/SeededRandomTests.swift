import XCTest
@testable import LiquidMetal2D

final class SeededRandomTests: XCTestCase {

    func testMatchesSplitMix64Reference() {
        // First outputs of SplitMix64 for seed 0, from the reference implementation.
        var rng = SeededRandom(seed: 0)
        XCTAssertEqual(rng.next(), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(rng.next(), 0x6E78_9E6A_A1B9_65F4)
        XCTAssertEqual(rng.next(), 0x06C4_5D18_8009_454F)
    }

    func testSameSeedSameSequence() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiffer() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testDrivesStandardLibraryRandomInRange() {
        var rng = SeededRandom(seed: 7)
        for _ in 0..<1000 {
            let value = Float.random(in: -2...2, using: &rng)
            XCTAssertGreaterThanOrEqual(value, -2)
            XCTAssertLessThanOrEqual(value, 2)
        }
    }
}
