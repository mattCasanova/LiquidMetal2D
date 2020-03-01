import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LiquidMetal2DTests.allTests),
    ]
}
#endif
