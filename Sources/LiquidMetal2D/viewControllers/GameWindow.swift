//
//  GameWindow.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/3/26.
//

import SwiftUI

#if canImport(UIKit)
/// The window a game runs in. On iOS there are no menus or window buttons
/// to guard, so this is a plain `WindowGroup`. The AppKit build has the same
/// name and API, so a game's `App` declares it once for both platforms:
///
/// ```swift
/// @main
/// struct MyGame: App {
///     var body: some SwiftUI.Scene {
///         GameWindow("My Game") {
///             LiquidView { GameViewController() }
///         }
///     }
/// }
/// ```
///
/// `fixedSize` only applies on the Mac; `title` names the window in the
/// iPad's window switcher.
public struct GameWindow<Content: View>: SwiftUI.Scene {
    private let title: String
    private let content: () -> Content

    public init(_ title: String, fixedSize: CGSize? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some SwiftUI.Scene {
        WindowGroup(title) {
            content()
        }
    }
}

#elseif canImport(AppKit)
/// The window a game runs in, set up so nothing quits or closes the game by
/// accident:
///
/// - One window (`Window`, not `WindowGroup`): no New Window, so never a
///   second engine.
/// - The close button and Command-W do nothing.
/// - Quit is gone from the menu, so Command-Q does nothing. The game quits
///   itself with ``LiquidApp/quit()`` from its own Quit button, after any
///   prompt it wants. Deliberate system quits (the Dock's Quit, log out,
///   restart, shut down) still go through.
/// - The document and editing menu items a game has no use for are gone.
///   Minimise, Hide and Full Screen stay.
///
/// The UIKit build has the same name and API, so a game's `App` declares it
/// once for both platforms (see the iOS doc comment for the example).
public struct GameWindow<Content: View>: SwiftUI.Scene {
    private let title: String
    private let fixedSize: CGSize?
    private let content: () -> Content

    /// - Parameters:
    ///   - title: The window's title.
    ///   - fixedSize: A size in points to lock the window to, or `nil` (the
    ///     default) for a resizable window. Full Screen works either way.
    ///   - content: The window's view, usually a `LiquidView` with SwiftUI
    ///     controls over it.
    public init(_ title: String, fixedSize: CGSize? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.fixedSize = fixedSize
        self.content = content
    }

    public var body: some SwiftUI.Scene {
        Window(title, id: "game") {
            sized(content())
                .windowDismissBehavior(.disabled)
        }
        .windowResizability(fixedSize == nil ? .automatic : .contentSize)
        .commands {
            GameCommands()
        }
    }

    @ViewBuilder
    private func sized(_ view: Content) -> some View {
        if let fixedSize {
            view.frame(width: fixedSize.width, height: fixedSize.height)
        } else {
            view
        }
    }
}

/// Empties the standard menu groups a game must not have (Quit) or has no
/// use for (documents, editing, printing, toolbars, help). Only groups the
/// default menu bar has: replacing one it lacks (`.textFormatting`) adds an
/// empty menu for it.
struct GameCommands: Commands {
    var body: some Commands {
        Group {
            CommandGroup(replacing: .appTermination) {}
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .importExport) {}
            CommandGroup(replacing: .printItem) {}
        }
        Group {
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            CommandGroup(replacing: .help) {}
        }
    }
}
#endif
