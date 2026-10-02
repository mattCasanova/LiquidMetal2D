//
//  InputDemo.swift
//  LiquidMetal2D-Demo
//
//  Created by Matt Casanova on 10/2/26.
//

import SwiftUI
import LiquidMetal2D

/// Shows the input layer: the pointer (hover and buttons), every touch
/// point, held keys, and the events the scene's observers hear.
///
/// **What the user sees:** a disc follows the pointer, dim while hovering (Mac
/// or iPad trackpad) and bright while a button or finger is down; a cyan disc
/// marks every finger on the screen. The panel reads out the pointer in
/// screen and world space, the scroll delta, the keys held right now, flashes
/// the last code triggered, and logs the observer callbacks.
///
/// **Engine features demonstrated:**
/// - Polling: `input.pointer`, `input.pointerWorld(forZ:)`, `isPressed`,
///   `isTriggered`, `isAnyTriggered`; the Mach 5 vocabulary.
/// - Combos: `isComboTriggered` with the either-side `.shift` and `.command`;
///   Shift-A and Command-B log a line. The combos are stored arrays, so the
///   per-frame check allocates nothing.
/// - Observers: `inputObservers.add(pointer:)` / `add(keyboard:)` on a
///   `DefaultScene`; only the current scene hears events, so push Pause and
///   the log stops.
/// - Devices: `ViewController` creates the engine with
///   `inputDevices: [.pointer, .keyboard]`; without `.keyboard` the key
///   queries here would trap.
/// - Actions: `DemoAction` (jump, move left, move right) through
///   `InputBindings`. Jump logs a line, the move axis reads -1, 0 or 1.
///   Rebind Jump captures the next key or button with `firstTriggeredCode()`;
///   Reset Jump puts the defaults back. Jump's defaults name `.gamepadA`,
///   which is skipped because the demo has no gamepad device.
class InputDemo: DefaultScene, PointerObserver, KeyboardObserver {
    override class var sceneType: any SceneType { SceneTypes.inputDemo }

    private let controls = InputControls()
    private var ui: DemoUI!

    private var pointerMarker: GameObj!
    private var touchMarkers: [GameObj] = []
    private var scrollTotal = Vec2()

    private static let keyboardCodes = InputCode.allCases.filter { $0.device == .keyboard }
    private static let shiftA: [InputCode] = [.shift, .a]
    private static let commandB: [InputCode] = [.command, .b]

    private var bindings = InputBindings<DemoAction>(defaults: [
        .jump: [.space, .w, .gamepadA],
        .moveLeft: [.a, .arrowLeft],
        .moveRight: [.d, .arrowRight]
    ])

    override func initialize(services: SceneServices) {
        super.initialize(services: services)
        renderer.setClearColor(color: TokyoNight.clearColor)

        pointerMarker = makeMarker(tint: TokyoNight.blue, scale: 1.5)
        for _ in 0..<10 {
            touchMarkers.append(makeMarker(tint: TokyoNight.cyan, scale: 1))
        }

        inputObservers.add(pointer: self)
        inputObservers.add(keyboard: self)

        ui = services.demoUI
        controls.onRebindJump = { [unowned self] in controls.isCapturing = true }
        controls.onResetJump = { [unowned self] in
            controls.isCapturing = false
            bindings.reset(.jump)
            showJumpBinding()
        }
        showJumpBinding()
        showOverlay()
    }

    override func resume() { showOverlay() }

    override func update(dt: Float) {
        let pointer = input.pointer
        scrollTotal += pointer.scrollDelta

        if let location = pointer.location, let world = input.pointerWorld(forZ: 0) {
            pointerMarker.isActive = true
            pointerMarker.position.set(world.x, world.y)
            let isDown = input.isPressed(.pointerPrimary) || input.isPressed(.pointerSecondary)
                || input.isPressed(.pointerMiddle)
            pointerMarker.get(AlphaBlendComponent.self)?.tintColor = isDown ? TokyoNight.blue : TokyoNight.darker
            controls.pointerText = String(
                format: "pointer  screen (%.0f, %.0f)  world (%.1f, %.1f)  %@",
                location.x, location.y, world.x, world.y, isDown ? buttonsHeld() : "hover")
        } else {
            pointerMarker.isActive = false
            controls.pointerText = "pointer  none"
        }

        for (index, marker) in touchMarkers.enumerated() {
            if index < pointer.touches.count {
                let world = renderer.unproject(screenWithWorldZ: pointer.touches[index].location.to3D(0))
                marker.isActive = true
                marker.position.set(world.x, world.y)
            } else {
                marker.isActive = false
            }
        }
        controls.touchesText = "touches  \(pointer.touches.count)"
        controls.scrollText = String(format: "scroll   total (%.0f, %.0f)", scrollTotal.x, scrollTotal.y)

        if input.isAnyTriggered, let code = InputDemo.keyboardCodes.first(where: input.isTriggered)
            ?? [InputCode.pointerPrimary, .pointerSecondary, .pointerMiddle].first(where: input.isTriggered) {
            controls.flash(code)
        }
        if input.isComboTriggered(InputDemo.shiftA) {
            controls.log("combo shift+a")
        }
        if input.isComboTriggered(InputDemo.commandB) {
            controls.log("combo command+b")
        }
        updateActions()
    }

    // MARK: - Actions

    private func updateActions() {
        if controls.isCapturing {
            // The captured press binds; it does not also jump.
            if let code = input.firstTriggeredCode() {
                bindings.set([code], for: .jump)
                controls.isCapturing = false
                controls.log("jump bound to \(code.name)")
                showJumpBinding()
            }
        } else if input.isTriggered(.jump, in: bindings) {
            controls.log("action jump")
        }
        let move = input.axis(negative: .moveLeft, positive: .moveRight, in: bindings)
        controls.moveText = String(format: "move     %+.0f", move)
    }

    private func showJumpBinding() {
        controls.jumpText = "jump     " + bindings.codes(for: .jump).map(\.name).joined(separator: " ")
    }

    override func shutdown() {
        super.shutdown()
        ui.overlay = nil
    }

    // MARK: - Observers

    func pointerTriggered(_ code: InputCode, at location: Vec2?) {
        controls.log("down  \(code) at \(describe(location))")
    }

    func pointerReleased(_ code: InputCode, at location: Vec2?) {
        controls.log("up    \(code) at \(describe(location))")
    }

    func keyTriggered(_ code: InputCode) {
        controls.log("down  \(code)")
        updateHeldKeys()
    }

    func keyReleased(_ code: InputCode) {
        controls.log("up    \(code)")
        updateHeldKeys()
    }

    // MARK: - Helpers

    private func buttonsHeld() -> String {
        var names: [String] = []
        if input.isPressed(.pointerPrimary) { names.append("primary") }
        if input.isPressed(.pointerSecondary) { names.append("secondary") }
        if input.isPressed(.pointerMiddle) { names.append("middle") }
        return names.joined(separator: "+")
    }

    private func updateHeldKeys() {
        let held = InputDemo.keyboardCodes.filter(input.isPressed).map { "\($0)" }
        controls.keysText = "keys     " + (held.isEmpty ? "none" : held.joined(separator: " "))
    }

    private func describe(_ location: Vec2?) -> String {
        location.map { String(format: "(%.0f, %.0f)", $0.x, $0.y) } ?? "nil"
    }

    private func makeMarker(tint: Vec4, scale: Float) -> GameObj {
        let marker = GameObj()
        marker.scale.set(scale, scale)
        marker.isActive = false
        marker.add(AlphaBlendComponent(parent: marker, textureID: GameTextures.disc, tintColor: tint))
        objects.append(marker)
        return marker
    }

    private func showOverlay() {
        ui.overlay = AnyView(InputPanel(controls: controls))
    }
}

/// The readouts of the input scene.
@MainActor
@Observable
final class InputControls {
    var pointerText = "pointer  none"
    var touchesText = "touches  0"
    var scrollText = "scroll   total (0, 0)"
    var keysText = "keys     none"
    var jumpText = ""
    var moveText = "move     +0"
    var isCapturing = false
    var onRebindJump: () -> Void = {}
    var onResetJump: () -> Void = {}
    private(set) var flashText = ""
    private(set) var flashOpacity = 0.0
    private(set) var logLines: [String] = []

    func flash(_ code: InputCode) {
        flashText = "\(code)"
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { flashOpacity = 1 }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) { flashOpacity = 0 }
    }

    func log(_ line: String) {
        logLines.insert(line, at: 0)
        if logLines.count > 12 { logLines.removeLast() }
    }
}

struct InputPanel: View {
    let controls: InputControls

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(controls.pointerText)
                Text(controls.touchesText)
                Text(controls.scrollText)
                Text(controls.keysText)
                Text(controls.isCapturing ? "jump     press a key or button…" : controls.jumpText)
                Text(controls.moveText)
            }
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(TokyoNight.color(TokyoNight.fg))
            .padding(.leading, 8)
            .padding(.top, 56)

            GeometryReader { geometry in
                Text(controls.flashText)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(TokyoNight.color(TokyoNight.blue))
                    .opacity(controls.flashOpacity)
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.2)
            }

            VStack(alignment: .trailing, spacing: 2) {
                ForEach(Array(controls.logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(TokyoNight.color(TokyoNight.comment))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.top, 56)

            BottomBar {
                Button(controls.isCapturing ? "Waiting…" : "Rebind Jump", action: controls.onRebindJump)
                Button("Reset Jump", action: controls.onResetJump)
            }
        }
    }
}

/// The demo's actions: what the scene asks about instead of keys.
enum DemoAction: String, InputAction {
    case jump, moveLeft, moveRight
}
