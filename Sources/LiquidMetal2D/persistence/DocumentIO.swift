//
//  DocumentIO.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/20/26.
//

import UIKit
import UniformTypeIdentifiers

/// User-facing file save/load via `UIDocumentPickerViewController`. Files
/// end up wherever the user chooses — iCloud Drive, Dropbox, Files.app
/// local, a third-party provider. Use this for exports, imports, and
/// anything the user should be able to manage themselves.
///
/// For app-managed persistence (save games, settings, caches), use
/// ``BlobStore`` / ``FileBlobStore`` instead.
///
/// Construct one instance at app startup with the `LiquidViewController`
/// subclass as the presenting view controller, and inject it into your
/// scene services. Scenes then call ``save(data:suggestedFilename:)``
/// and ``load(contentTypes:)`` without knowing anything about UIKit.
@MainActor
public final class DocumentIO {

    /// User-initiated and lifecycle failures. I/O errors propagate as
    /// their underlying type (Cocoa filesystem errors etc.).
    public enum Error: Swift.Error {
        /// The user dismissed the picker without picking a file.
        case userCancelled
        /// The presenting view controller has been deallocated — the
        /// app is likely shutting down.
        case noPresentingViewController
    }

    private weak var presentingVC: UIViewController?

    /// Creates a DocumentIO that presents pickers from `presentingVC`.
    /// The reference is weak; in a LiquidMetal2D app the presenting VC
    /// is the root `LiquidViewController` subclass, which lives for the
    /// lifetime of the app.
    public init(presentingVC: UIViewController) {
        self.presentingVC = presentingVC
    }

    /// Presents a system picker so the user chooses where to save `data`.
    /// The file is written to a temporary location first, then the picker
    /// moves it to the user's destination. Temp is cleaned up in both the
    /// success and cancellation paths.
    ///
    /// - Parameters:
    ///   - data: The bytes to save.
    ///   - suggestedFilename: Filename (including extension) shown in
    ///     the picker as the default.
    /// - Throws: ``Error/userCancelled`` on dismiss;
    ///   ``Error/noPresentingViewController`` if the presenting VC has
    ///   been deallocated; Cocoa errors on write failures.
    public func save(data: Data, suggestedFilename: String) async throws {
        guard let vc = presentingVC else {
            throw Error.noPresentingViewController
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent(suggestedFilename)

        do {
            try data.write(to: tempURL, options: .atomic)

            let picker = UIDocumentPickerViewController(
                forExporting: [tempURL], asCopy: false)

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Swift.Error>) in
                let coordinator = SaveCoordinator(
                    continuation: continuation, tempDir: tempDir)
                picker.delegate = coordinator
                vc.present(picker, animated: true)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        }
    }

    /// Presents a system picker so the user chooses a file to load.
    /// Handles the security-scoped URL dance required for files outside
    /// the app sandbox.
    ///
    /// - Parameter contentTypes: File types the picker will let the user
    ///   select.
    /// - Returns: The contents of the chosen file.
    /// - Throws: ``Error/userCancelled`` on dismiss;
    ///   ``Error/noPresentingViewController`` if the presenting VC has
    ///   been deallocated; Cocoa errors on read failures.
    public func load(contentTypes: [UTType]) async throws -> Data {
        guard let vc = presentingVC else {
            throw Error.noPresentingViewController
        }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = false

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Data, Swift.Error>) in
            let coordinator = LoadCoordinator(continuation: continuation)
            picker.delegate = coordinator
            vc.present(picker, animated: true)
        }
    }
}

// MARK: - Internal delegates

/// Self-retaining coordinator. `UIDocumentPickerViewController.delegate`
/// is weak, so the coordinator must hold itself alive until one of its
/// callbacks fires. `selfRef = self` in `init` establishes the retain;
/// setting it to `nil` inside each callback breaks it exactly once.
@MainActor
private final class SaveCoordinator: NSObject, UIDocumentPickerDelegate {
    private var selfRef: SaveCoordinator?
    private let continuation: CheckedContinuation<Void, Swift.Error>
    private let tempDir: URL

    init(continuation: CheckedContinuation<Void, Swift.Error>, tempDir: URL) {
        self.continuation = continuation
        self.tempDir = tempDir
        super.init()
        self.selfRef = self
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        try? FileManager.default.removeItem(at: tempDir)
        continuation.resume()
        selfRef = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        try? FileManager.default.removeItem(at: tempDir)
        continuation.resume(throwing: DocumentIO.Error.userCancelled)
        selfRef = nil
    }
}

@MainActor
private final class LoadCoordinator: NSObject, UIDocumentPickerDelegate {
    private var selfRef: LoadCoordinator?
    private let continuation: CheckedContinuation<Data, Swift.Error>

    init(continuation: CheckedContinuation<Data, Swift.Error>) {
        self.continuation = continuation
        super.init()
        self.selfRef = self
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        defer { selfRef = nil }

        guard let url = urls.first else {
            continuation.resume(throwing: DocumentIO.Error.userCancelled)
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            continuation.resume(returning: data)
        } catch {
            continuation.resume(throwing: error)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation.resume(throwing: DocumentIO.Error.userCancelled)
        selfRef = nil
    }
}
