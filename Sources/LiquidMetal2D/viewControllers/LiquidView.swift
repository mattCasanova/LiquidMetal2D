import SwiftUI
import UIKit

/// SwiftUI bridge that hosts a ``LiquidViewController`` inside a SwiftUI
/// view tree. Use this when building a SwiftUI app that wants the Metal
/// game/preview surface as one pane in a larger layout.
///
/// ```swift
/// struct EditorScreen: View {
///     var body: some View {
///         HStack {
///             LiquidView { EditorVC() }    // Metal preview
///             ControlPanel()               // SwiftUI controls
///         }
///     }
/// }
/// ```
///
/// Touches inside the Metal pane are handled by ``LiquidViewController``
/// as in any UIKit app. Touches on SwiftUI controls are eaten by SwiftUI
/// and never reach the view controller — the two compose without conflict.
///
/// This wrapper centralizes the dismantle/shutdown step, which is easy to
/// forget when writing the bridge by hand and would otherwise leak the
/// engine and its display link.
@MainActor
public struct LiquidView: UIViewControllerRepresentable {
    private let buildVC: @MainActor () -> LiquidViewController

    /// - Parameter buildVC: Closure that produces a configured
    ///   ``LiquidViewController`` subclass. Called once when SwiftUI
    ///   instantiates the underlying UIKit view controller.
    public init(buildVC: @escaping @MainActor () -> LiquidViewController) {
        self.buildVC = buildVC
    }

    public func makeUIViewController(context: Context) -> LiquidViewController {
        buildVC()
    }

    public func updateUIViewController(_ vc: LiquidViewController, context: Context) {}

    public static func dismantleUIViewController(
        _ vc: LiquidViewController, coordinator: ()
    ) {
        vc.gameEngine?.shutdown()
    }
}
