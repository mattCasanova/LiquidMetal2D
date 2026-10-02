import XCTest
@testable import LiquidMetal2D

/// Input events reach the current scene's observers, and only that scene's.
/// Runs the real engine loop on a fake clock; needs the host's Metal device.
@MainActor
final class InputDeliveryTests: XCTestCase {

    func testObserversHearTheFrameEventsInOrder() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        let scene = ListeningScene.current!

        engine.enqueue(.down(.space))
        engine.enqueue(.pointerMoved(Vec2(3, 4)))
        engine.enqueue(.down(.pointerPrimary))
        engine.enqueue(.up(.space))
        clock.advance(by: 1.0 / 60)

        XCTAssertEqual(scene.log, ["key down space", "pointer down pointerPrimary at (3.0, 4.0)", "key up space"])
        XCTAssertEqual(scene.updates, 1, "delivery happens before update, on the same frame")
        engine.shutdown()
    }

    func testOnlyTheCurrentSceneHearsEvents() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        let below = ListeningScene.current!
        engine.sceneManager.pushScene(type: TestScenes.second)
        clock.advance(by: 1.0 / 60)
        let above = ListeningScene.current!
        XCTAssertTrue(above !== below)

        engine.enqueue(.down(.a))
        clock.advance(by: 1.0 / 60)

        XCTAssertEqual(above.log, ["key down a"])
        XCTAssertEqual(below.log, [])

        engine.sceneManager.popScene()
        clock.advance(by: 1.0 / 60)
        engine.enqueue(.down(.b))
        clock.advance(by: 1.0 / 60)

        XCTAssertEqual(below.log, ["key down b"], "the lower scene hears again after the pop")
        XCTAssertEqual(above.log, ["key down a"])
        engine.shutdown()
    }

    func testTransitionFrameDropsItsEvents() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        let first = ListeningScene.current!
        engine.sceneManager.setScene(type: TestScenes.second)
        engine.enqueue(.down(.escape))

        clock.advance(by: 1.0 / 60)

        let second = ListeningScene.current!
        XCTAssertEqual(first.log, [])
        XCTAssertEqual(second.log, [], "the click that opened the scene does not press anything in it")
        clock.advance(by: 1.0 / 60)
        XCTAssertEqual(second.log, [])
        XCTAssertFalse(engine.input.isTriggered(.escape), "and the trigger lasted only that frame")
        XCTAssertTrue(engine.input.isPressed(.escape))
        engine.shutdown()
    }

    func testShutdownClearsTheObservers() throws {
        let (engine, clock) = try makeEngine()
        engine.run()
        let scene = ListeningScene.current!
        engine.sceneManager.setScene(type: TestScenes.second)
        clock.advance(by: 1.0 / 60)

        scene.inputObservers.deliver([.triggered(.a)], from: engine.input)

        XCTAssertEqual(scene.log, [], "a shut-down scene has no observers left")
        engine.shutdown()
    }

    func testDeadObserversAreNotKeptAlive() {
        let observers = InputObservers()
        var observer: Recorder? = Recorder()
        weak var weakObserver = observer
        observers.add(keyboard: observer!)
        observer = nil

        XCTAssertNil(weakObserver, "the list holds observers weakly")
        let input = InputSystem(devices: [.keyboard], unproject: { $0 })
        observers.deliver([.triggered(.a)], from: input)   // nothing to call, nothing to crash
    }

    func testRemoveDropsAnObserverFromEveryList() {
        let observers = InputObservers()
        let input = InputSystem(devices: [.pointer, .keyboard, .gamepad], unproject: { $0 })
        let recorder = Recorder()
        observers.add(pointer: recorder)
        observers.add(keyboard: recorder)
        observers.add(gamepad: recorder)

        observers.deliver([.triggered(.a), .triggered(.pointerPrimary), .gamepadConnected], from: input)
        XCTAssertEqual(recorder.log, ["key down a", "pointer down pointerPrimary at nil", "gamepad connected true"])

        observers.remove(recorder)
        observers.deliver([.triggered(.b)], from: input)
        XCTAssertEqual(recorder.log.count, 3)
    }

    private func makeEngine() throws -> (DefaultEngine, FakeClock) {
        _ = try ShaderTestSupport.makeDevice()
        let factory = SceneFactory()
        factory.addScenes([ListeningScene.self, SecondListeningScene.self])
        let clock = FakeClock()
        let engine = DefaultEngine(
            renderer: DefaultRenderer(parentView: PlatformView(), maxObjects: 1),
            documents: DocumentIO(presentingVC: PlatformViewController()),
            inputDevices: [.pointer, .keyboard],
            initialSceneType: TestScenes.first,
            sceneFactory: factory,
            clock: clock)
        return (engine, clock)
    }
}

private enum TestScenes: SceneType {
    case first, second
}

/// Logs what its observers hear.
@MainActor
private final class Recorder: PointerObserver, KeyboardObserver, GamepadObserver {
    private(set) var log: [String] = []

    func pointerTriggered(_ code: InputCode, at location: Vec2?) {
        log.append("pointer down \(code) at \(location.map { "(\($0.x), \($0.y))" } ?? "nil")")
    }
    func pointerReleased(_ code: InputCode, at location: Vec2?) {
        log.append("pointer up \(code)")
    }
    func keyTriggered(_ code: InputCode) { log.append("key down \(code)") }
    func keyReleased(_ code: InputCode) { log.append("key up \(code)") }
    func gamepadTriggered(_ code: InputCode) { log.append("gamepad down \(code)") }
    func gamepadReleased(_ code: InputCode) { log.append("gamepad up \(code)") }
    func gamepadConnectionChanged(isConnected: Bool) { log.append("gamepad connected \(isConnected)") }
}

/// A scene that observes its own input. Draws nothing.
@MainActor
private class ListeningScene: DefaultScene, PointerObserver, KeyboardObserver {
    static var current: ListeningScene!
    private(set) var log: [String] = []
    private(set) var updates = 0

    override class var sceneType: any SceneType { TestScenes.first }

    required init() {
        super.init()
        ListeningScene.current = self
    }

    override func initialize(services: SceneServices) {
        super.initialize(services: services)
        inputObservers.add(pointer: self)
        inputObservers.add(keyboard: self)
    }

    override func update(dt: Float) { updates += 1 }
    override func draw() {}

    func pointerTriggered(_ code: InputCode, at location: Vec2?) {
        log.append("pointer down \(code) at \(location.map { "(\($0.x), \($0.y))" } ?? "nil")")
    }
    func pointerReleased(_ code: InputCode, at location: Vec2?) { log.append("pointer up \(code)") }
    func keyTriggered(_ code: InputCode) { log.append("key down \(code)") }
    func keyReleased(_ code: InputCode) { log.append("key up \(code)") }
}

@MainActor
private final class SecondListeningScene: ListeningScene {
    override static var sceneType: any SceneType { TestScenes.second }
}
