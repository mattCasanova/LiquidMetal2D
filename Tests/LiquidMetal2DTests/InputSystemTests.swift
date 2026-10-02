import XCTest
@testable import LiquidMetal2D

/// The per-frame input snapshot: pure logic, no engine, no platform.
@MainActor
final class InputSystemTests: XCTestCase {

    private func makeInput(_ devices: InputDevices = [.pointer, .keyboard]) -> InputSystem {
        InputSystem(devices: devices, unproject: { $0 })
    }

    // MARK: - Buttons

    func testDownIsTriggeredAndPressedThenRepeating() {
        let input = makeInput()
        input.enqueue(.down(.space))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.triggered(.space)])
        XCTAssertTrue(input.isTriggered(.space))
        XCTAssertTrue(input.isPressed(.space))
        XCTAssertFalse(input.isRepeating(.space))
        XCTAssertTrue(input.isAnyTriggered)

        XCTAssertEqual(input.beginFrame(), [])
        XCTAssertFalse(input.isTriggered(.space))
        XCTAssertTrue(input.isPressed(.space))
        XCTAssertTrue(input.isRepeating(.space))
        XCTAssertFalse(input.isAnyTriggered)
    }

    func testUpIsReleasedForOneFrame() {
        let input = makeInput()
        input.enqueue(.down(.a))
        input.beginFrame()
        input.enqueue(.up(.a))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.released(.a)])
        XCTAssertTrue(input.isReleased(.a))
        XCTAssertFalse(input.isPressed(.a))
        XCTAssertFalse(input.isRepeating(.a))

        input.beginFrame()
        XCTAssertFalse(input.isReleased(.a))
        XCTAssertFalse(input.isPressed(.a))
    }

    func testTapInsideOneFrameIsTriggeredAndReleasedNotPressed() {
        let input = makeInput()
        input.enqueue(.down(.pointerPrimary))
        input.enqueue(.up(.pointerPrimary))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.triggered(.pointerPrimary), .released(.pointerPrimary)])
        XCTAssertTrue(input.isTriggered(.pointerPrimary))
        XCTAssertTrue(input.isReleased(.pointerPrimary))
        XCTAssertFalse(input.isPressed(.pointerPrimary))
    }

    func testOSKeyRepeatIsOneTrigger() {
        let input = makeInput()
        input.enqueue(.down(.w))
        input.enqueue(.down(.w))
        input.enqueue(.down(.w))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.triggered(.w)])
        XCTAssertTrue(input.isPressed(.w))
        input.enqueue(.down(.w))
        XCTAssertEqual(input.beginFrame(), [])
        XCTAssertTrue(input.isRepeating(.w))
    }

    func testUpWithoutDownIsNothing() {
        let input = makeInput()
        input.enqueue(.up(.escape))

        XCTAssertEqual(input.beginFrame(), [])
        XCTAssertFalse(input.isReleased(.escape))
    }

    func testFocusLostReleasesEverythingHeld() {
        let input = makeInput()
        input.enqueue(.down(.leftShift))
        input.enqueue(.down(.d))
        input.enqueue(.pointerMoved(Vec2(3, 4)))
        input.enqueue(.down(.pointerPrimary))
        input.beginFrame()
        input.enqueue(.focusLost)

        let events = input.beginFrame()

        XCTAssertEqual(Set(events), [.released(.leftShift), .released(.shift), .released(.d), .released(.pointerPrimary)])
        XCTAssertTrue(input.isReleased(.d))
        XCTAssertFalse(input.isPressed(.leftShift))
        XCTAssertFalse(input.isPressed(.pointerPrimary))
        XCTAssertNil(input.pointer.location, "focus loss takes the pointer away too")
    }

    func testEventsInOneFrameKeepTheirOrder() {
        let input = makeInput()
        input.enqueue(.down(.a))
        input.enqueue(.down(.b))
        input.enqueue(.up(.a))
        input.enqueue(.down(.c))

        XCTAssertEqual(input.beginFrame(), [.triggered(.a), .triggered(.b), .released(.a), .triggered(.c)])
    }

    // MARK: - Pointer

    func testHoverSetsTheLocationWithoutATouch() {
        let input = makeInput()
        input.enqueue(.pointerMoved(Vec2(10, 20)))

        input.beginFrame()

        XCTAssertEqual(input.pointer.location, Vec2(10, 20))
        XCTAssertFalse(input.isPressed(.pointerPrimary))
        XCTAssertNil(input.getScreenTouch(), "a hover is not a touch")
        XCTAssertEqual(input.pointerWorld(forZ: 5), Vec3(10, 20, 5))
        XCTAssertNil(input.getWorldTouch(forZ: 5))
    }

    func testPointerLeavingTheViewClearsTheLocation() {
        let input = makeInput()
        input.enqueue(.pointerMoved(Vec2(1, 1)))
        input.beginFrame()
        input.enqueue(.pointerMoved(nil))

        input.beginFrame()

        XCTAssertNil(input.pointer.location)
        XCTAssertNil(input.pointerWorld(forZ: 0))
    }

    func testScrollSumsOverTheFrameAndResets() {
        let input = makeInput()
        input.enqueue(.scroll(Vec2(0, 1)))
        input.enqueue(.scroll(Vec2(2, -3)))

        input.beginFrame()
        XCTAssertEqual(input.pointer.scrollDelta, Vec2(2, -2))

        input.beginFrame()
        XCTAssertEqual(input.pointer.scrollDelta, Vec2())
    }

    // MARK: - Touches

    func testFirstFingerIsThePointer() {
        let input = makeInput()
        input.enqueue(.touchBegan(id: 7, Vec2(10, 10)))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.triggered(.pointerPrimary)])
        XCTAssertEqual(input.pointer.location, Vec2(10, 10))
        XCTAssertEqual(input.pointer.touches, [TouchPoint(id: 7, location: Vec2(10, 10))])
        XCTAssertEqual(input.getScreenTouch(), Vec2(10, 10))
    }

    func testSecondFingerJoinsTheListWithoutMovingThePointer() {
        let input = makeInput()
        input.enqueue(.touchBegan(id: 1, Vec2(10, 10)))
        input.enqueue(.touchBegan(id: 2, Vec2(50, 50)))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.triggered(.pointerPrimary)], "one press, however many fingers")
        XCTAssertEqual(input.pointer.location, Vec2(10, 10))
        XCTAssertEqual(input.pointer.touches.map(\.id), [1, 2])

        input.enqueue(.touchMoved(id: 2, Vec2(60, 60)))
        input.enqueue(.touchMoved(id: 1, Vec2(12, 12)))
        input.beginFrame()
        XCTAssertEqual(input.pointer.location, Vec2(12, 12))
        XCTAssertEqual(input.pointer.touches, [
            TouchPoint(id: 1, location: Vec2(12, 12)), TouchPoint(id: 2, location: Vec2(60, 60)),
        ])
    }

    func testLiftingThePointerFingerHandsOverToTheNextOne() {
        let input = makeInput()
        input.enqueue(.touchBegan(id: 1, Vec2(10, 10)))
        input.enqueue(.touchBegan(id: 2, Vec2(50, 50)))
        input.beginFrame()
        input.enqueue(.touchEnded(id: 1))

        let events = input.beginFrame()

        XCTAssertEqual(events, [], "the primary button stays down while a finger remains")
        XCTAssertTrue(input.isPressed(.pointerPrimary))
        XCTAssertEqual(input.pointer.location, Vec2(50, 50))
        XCTAssertEqual(input.pointer.touches.map(\.id), [2])

        input.enqueue(.touchEnded(id: 2))
        XCTAssertEqual(input.beginFrame(), [.released(.pointerPrimary)])
        XCTAssertNil(input.pointer.location)
        XCTAssertTrue(input.pointer.touches.isEmpty)
    }

    func testLiftingAnotherFingerKeepsThePointer() {
        let input = makeInput()
        input.enqueue(.touchBegan(id: 1, Vec2(10, 10)))
        input.enqueue(.touchBegan(id: 2, Vec2(50, 50)))
        input.beginFrame()
        input.enqueue(.touchEnded(id: 2))

        XCTAssertEqual(input.beginFrame(), [])
        XCTAssertEqual(input.pointer.location, Vec2(10, 10))
        XCTAssertEqual(input.pointer.touches.map(\.id), [1])
    }

    func testFocusLostClearsTheTouches() {
        let input = makeInput()
        input.enqueue(.touchBegan(id: 1, Vec2(10, 10)))
        input.enqueue(.touchBegan(id: 2, Vec2(50, 50)))
        input.beginFrame()
        input.enqueue(.focusLost)

        XCTAssertEqual(input.beginFrame(), [.released(.pointerPrimary)])
        XCTAssertTrue(input.pointer.touches.isEmpty)
        XCTAssertNil(input.pointer.location)
    }

    func testTouchesAboveTheCapAreDropped() {
        let input = makeInput()
        for id in 0..<12 {
            input.enqueue(.touchBegan(id: id, Vec2(Float(id), 0)))
        }
        input.beginFrame()

        XCTAssertEqual(input.pointer.touches.count, 10)
        input.enqueue(.touchEnded(id: 11))
        input.beginFrame()
        XCTAssertEqual(input.pointer.touches.count, 10, "the dropped finger's end is ignored")
    }

    // MARK: - The one-touch API

    func testSetTouchMatchesTheOldBehaviour() {
        let input = makeInput()
        XCTAssertNil(input.getScreenTouch())

        input.setTouch(location: Vec2(5, 6))
        input.beginFrame()
        XCTAssertEqual(input.getScreenTouch(), Vec2(5, 6))
        XCTAssertEqual(input.getWorldTouch(forZ: 2), Vec3(5, 6, 2))
        XCTAssertTrue(input.isTriggered(.pointerPrimary))

        input.setTouch(location: Vec2(7, 8))
        input.beginFrame()
        XCTAssertEqual(input.getScreenTouch(), Vec2(7, 8), "a drag moves the touch without a new press")
        XCTAssertFalse(input.isTriggered(.pointerPrimary))
        XCTAssertTrue(input.isRepeating(.pointerPrimary))

        input.setTouch(location: nil)
        input.beginFrame()
        XCTAssertNil(input.getScreenTouch())
        XCTAssertNil(input.getWorldTouch(forZ: 2))
        XCTAssertTrue(input.isReleased(.pointerPrimary))
        XCTAssertNil(input.pointer.location)
    }

    func testTouchStateChangesOnlyAtTheFrame() {
        let input = makeInput()
        input.setTouch(location: Vec2(1, 2))

        XCTAssertNil(input.getScreenTouch(), "queued, not yet applied")
        input.beginFrame()
        XCTAssertEqual(input.getScreenTouch(), Vec2(1, 2))
    }

    // MARK: - Devices

    func testEventsForADisabledDeviceAreDropped() {
        let input = makeInput([.pointer])
        input.enqueue(.down(.space))
        input.enqueue(.down(.pointerPrimary))

        let events = input.beginFrame()

        XCTAssertEqual(events, [.triggered(.pointerPrimary)])
        XCTAssertTrue(input.isAnyTriggered)
        // Asking about the keyboard here would trap: InputSystem.requireEnabled is a
        // preconditionFailure, documented rather than tested.
    }

    func testFocusLostIsAcceptedWhateverTheDevices() {
        let input = makeInput([.keyboard])
        input.enqueue(.down(.q))
        input.beginFrame()
        input.enqueue(.focusLost)

        XCTAssertEqual(input.beginFrame(), [.released(.q)])
    }

    func testEveryCodeHasADeviceAndCodesIndexTheTables() {
        for (index, code) in InputCode.allCases.enumerated() {
            XCTAssertEqual(code.rawValue, index, "\(code) must index the state tables")
            XCTAssertFalse(code.device.isEmpty, "\(code) has no device")
        }
        XCTAssertEqual(InputCode.a.device, .keyboard)
        XCTAssertEqual(InputCode.pointerMiddle.device, .pointer)
        XCTAssertEqual(InputCode.gamepadMenu.device, .gamepad)
    }
}
