//
//  InputSystem.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/2/26.
//

/// The engine's input state. Platform code only ``enqueue(_:)``s raw events;
/// once per frame the engine calls ``beginFrame()``, which drains the queue
/// in order into the per-code state and returns the frame's ``InputEvent``s.
/// Polling (``InputReader``) and observers both come from that one drain.
///
/// ```
/// OS callbacks ──enqueue──▶ queue ──beginFrame()──▶ state ──▶ isPressed / isTriggered / …
///                                                       └──▶ [InputEvent] ──▶ current scene
/// ```
///
/// State per code is `down` now, `down` last frame, and two per-frame flags.
/// The tables are arrays indexed by ``InputCode``'s raw value; a frame
/// allocates nothing once the queue has grown to its working size.
@MainActor
public final class InputSystem: InputReader, InputWriter {
    /// The devices the engine was created with.
    public let devices: InputDevices

    private let unproject: (Vec3) -> Vec3

    private var queue: [RawInputEvent] = []
    private var frameEvents: [InputEvent] = []

    private var down: [Bool]
    private var downLastFrame: [Bool]
    private var triggeredThisFrame: [Bool]
    private var releasedThisFrame: [Bool]
    private var triggeredCount = 0

    private var pointerLocation: Vec2?
    private var scrollDelta = Vec2()
    /// Fingers down, oldest first. The first is also the pointer.
    private var touches: [TouchPoint] = []
    /// Fingers an iPad can report; the array never grows past it.
    private static let maxTouches = 10
    /// Devices already reported for feeding a disabled device, so the
    /// warning prints once per device, not once per event.
    private var reportedDisabled: InputDevices = []

    /// - Parameters:
    ///   - devices: Which devices accept events and may be queried.
    ///   - unproject: Screen point with a world z to a world point; the
    ///     renderer's `unproject(screenWithWorldZ:)`. Tests pass `{ $0 }`.
    public init(devices: InputDevices, unproject: @escaping (Vec3) -> Vec3) {
        self.devices = devices
        self.unproject = unproject
        let count = InputCode.allCases.count
        down = Array(repeating: false, count: count)
        downLastFrame = down
        triggeredThisFrame = down
        releasedThisFrame = down
        queue.reserveCapacity(64)
        frameEvents.reserveCapacity(64)
        touches.reserveCapacity(InputSystem.maxTouches)
    }

    // MARK: - Frame

    /// Drains the queue into the state tables and returns this frame's
    /// events in order. The engine calls it at the top of every frame.
    @discardableResult
    public func beginFrame() -> [InputEvent] {
        for index in down.indices {
            downLastFrame[index] = down[index]
            triggeredThisFrame[index] = false
            releasedThisFrame[index] = false
        }
        triggeredCount = 0
        scrollDelta = Vec2()
        frameEvents.removeAll(keepingCapacity: true)

        for event in queue {
            apply(event)
        }
        queue.removeAll(keepingCapacity: true)
        return frameEvents
    }

    private func apply(_ event: RawInputEvent) {
        switch event {
        case .down(let code):
            press(code)
        case .up(let code):
            release(code)
        case .pointerMoved(let location):
            pointerLocation = location
        case .scroll(let delta):
            scrollDelta += delta
        case .touchBegan(let id, let location):
            beginTouch(id: id, at: location)
        case .touchMoved(let id, let location):
            moveTouch(id: id, to: location)
        case .touchEnded(let id):
            endTouch(id: id)
        case .focusLost:
            loseFocus()
        }
    }

    private func loseFocus() {
        for code in InputCode.allCases where down[code.rawValue] {
            release(code)
        }
        pointerLocation = nil
        touches.removeAll(keepingCapacity: true)
    }

    private func press(_ code: InputCode) {
        let index = code.rawValue
        // A second down while already down is OS key repeat.
        guard !down[index] else { return }
        down[index] = true
        triggeredThisFrame[index] = true
        triggeredCount += 1
        frameEvents.append(.triggered(code))
    }

    private func release(_ code: InputCode) {
        let index = code.rawValue
        guard down[index] else { return }
        down[index] = false
        releasedThisFrame[index] = true
        frameEvents.append(.released(code))
    }

    // MARK: - Touches

    private func beginTouch(id: Int, at location: Vec2) {
        guard touches.count < InputSystem.maxTouches else {
            DebugPrint("InputSystem: more than %d touches; dropping touch %d", InputSystem.maxTouches, id)
            return
        }
        guard !touches.contains(where: { $0.id == id }) else {
            preconditionFailure("InputSystem: touch \(id) began twice without ending")
        }
        touches.append(TouchPoint(id: id, location: location))
        if touches.count == 1 {
            pointerLocation = location
            press(.pointerPrimary)
        }
    }

    private func moveTouch(id: Int, to location: Vec2) {
        guard let index = touches.firstIndex(where: { $0.id == id }) else {
            // A move for a finger the system never saw begin: the platform
            // layer is miswired, or the touch was dropped above the cap.
            DebugPrint("InputSystem: move for unknown touch %d", id)
            return
        }
        touches[index] = TouchPoint(id: id, location: location)
        if index == 0 {
            pointerLocation = location
        }
    }

    private func endTouch(id: Int) {
        guard let index = touches.firstIndex(where: { $0.id == id }) else {
            DebugPrint("InputSystem: end for unknown touch %d", id)
            return
        }
        touches.remove(at: index)
        guard index == 0 else { return }
        // The pointer finger lifted: the next oldest finger takes over, or
        // the pointer goes away.
        if let next = touches.first {
            pointerLocation = next.location
        } else {
            pointerLocation = nil
            release(.pointerPrimary)
        }
    }

    // MARK: - InputWriter

    /// Queues an event for the next frame. Events for a device that is not
    /// enabled are dropped: a source feeding a disabled device is a wiring
    /// bug, reported once per device in Debug builds.
    public func enqueue(_ event: RawInputEvent) {
        let device: InputDevices
        switch event {
        case .down(let code), .up(let code):
            device = code.device
        case .pointerMoved, .scroll, .touchBegan, .touchMoved, .touchEnded:
            device = .pointer
        case .focusLost:
            queue.append(event)
            return
        }
        guard devices.contains(device) else {
            if !reportedDisabled.contains(device) {
                reportedDisabled.insert(device)
                DebugPrint("InputSystem: dropping %@ events; the engine was created without that device",
                           device.name)
            }
            return
        }
        queue.append(event)
    }

    public func setTouch(location: Vec2?) {
        if let location {
            enqueue(.pointerMoved(location))
            enqueue(.down(.pointerPrimary))
        } else {
            enqueue(.up(.pointerPrimary))
            enqueue(.pointerMoved(nil))
        }
    }

    // MARK: - InputReader

    public func isPressed(_ code: InputCode) -> Bool {
        requireEnabled(code)
        return down[code.rawValue]
    }

    public func isTriggered(_ code: InputCode) -> Bool {
        requireEnabled(code)
        return triggeredThisFrame[code.rawValue]
    }

    public func isReleased(_ code: InputCode) -> Bool {
        requireEnabled(code)
        return releasedThisFrame[code.rawValue]
    }

    public func isRepeating(_ code: InputCode) -> Bool {
        requireEnabled(code)
        return down[code.rawValue] && downLastFrame[code.rawValue]
    }

    public var isAnyTriggered: Bool { triggeredCount > 0 }

    public var pointer: PointerState {
        requireEnabled(.pointer)
        return PointerState(location: pointerLocation, scrollDelta: scrollDelta, touches: touches)
    }

    public func pointerWorld(forZ z: Float) -> Vec3? {
        requireEnabled(.pointer)
        return pointerLocation.map { unproject($0.to3D(z)) }
    }

    public func getScreenTouch() -> Vec2? {
        isPressed(.pointerPrimary) ? pointerLocation : nil
    }

    public func getWorldTouch(forZ z: Float) -> Vec3? {
        getScreenTouch().map { unproject($0.to3D(z)) }
    }

    private func requireEnabled(_ code: InputCode) {
        requireEnabled(code.device)
    }

    private func requireEnabled(_ device: InputDevices) {
        guard devices.contains(device) else {
            preconditionFailure(
                "InputSystem: \(device.name) is not enabled; pass .\(device.name) in DefaultEngine(inputDevices:)")
        }
    }
}
