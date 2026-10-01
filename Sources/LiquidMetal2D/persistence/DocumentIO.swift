//
//  DocumentIO.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 4/20/26.
//

import Foundation
import UniformTypeIdentifiers

/// User-facing file save/load via the system file picker. Files end up
/// wherever the user chooses — iCloud Drive, Dropbox, Files.app local, a
/// third-party provider; on the Mac, any folder. Use this for exports, imports, and
/// anything the user should be able to manage themselves.
///
/// For app-managed persistence (save games, settings, caches), use
/// ``BlobStore`` / ``FileBlobStore`` instead.
///
/// Construct one instance at app startup with the `LiquidViewController`
/// subclass as the presenting view controller, and inject it into your
/// scene services. Scenes then call ``save(data:suggestedFilename:)``
/// and ``load(contentTypes:)`` without knowing anything about UIKit or
/// AppKit. Each platform's backend lives in its own `DocumentIO+…` file.
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

    weak var presentingVC: PlatformViewController?

    /// Creates a DocumentIO that presents pickers from `presentingVC`.
    /// The reference is weak; in a LiquidMetal2D app the presenting VC
    /// is the root `LiquidViewController` subclass, which lives for the
    /// lifetime of the app.
    public init(presentingVC: PlatformViewController) {
        self.presentingVC = presentingVC
    }
}
