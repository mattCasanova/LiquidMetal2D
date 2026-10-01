//
//  DocumentIO+AppKit.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 10/1/26.
//

#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import UniformTypeIdentifiers

extension DocumentIO {
    /// Presents a save panel as a sheet on the presenting view's window and
    /// writes `data` to the chosen URL. No temp file: the panel hands back a
    /// URL the app may write to.
    ///
    /// - Parameters:
    ///   - data: The bytes to save.
    ///   - suggestedFilename: Filename (including extension) shown in the
    ///     panel as the default.
    /// - Throws: ``Error/userCancelled`` on cancel; ``Error/pickerUnavailable`` if
    ///   the panel could not be shown; ``Error/noPresentingViewController`` if the
    ///   presenting VC is gone or has no window; Cocoa errors on write failures.
    public func save(data: Data, suggestedFilename: String) async throws {
        let window = try presentingWindow()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true

        let url = try await present(panel, on: window)
        try data.write(to: url, options: .atomic)
    }

    /// Presents an open panel as a sheet on the presenting view's window and
    /// reads the chosen file.
    ///
    /// - Parameter contentTypes: File types the panel will let the user select.
    /// - Returns: The contents of the chosen file.
    /// - Throws: ``Error/userCancelled`` on cancel; ``Error/pickerUnavailable`` if
    ///   the panel could not be shown; ``Error/noPresentingViewController`` if the
    ///   presenting VC is gone or has no window; Cocoa errors on read failures.
    public func load(contentTypes: [UTType]) async throws -> Data {
        let window = try presentingWindow()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let url = try await present(panel, on: window)
        return try Data(contentsOf: url)
    }

    /// Runs the panel as a sheet and returns the chosen URL.
    private func present(_ panel: NSSavePanel, on window: NSWindow) async throws -> URL {
        switch await panel.beginSheetModal(for: window) {
        case .OK:
            guard let url = panel.url else {
                preconditionFailure("the panel returned OK with no URL")
            }
            return url
        case .abort:
            throw Error.pickerUnavailable
        default:
            throw Error.userCancelled
        }
    }

    private func presentingWindow() throws -> NSWindow {
        guard let window = presentingVC?.view.window else {
            throw Error.noPresentingViewController
        }
        return window
    }
}
#endif
