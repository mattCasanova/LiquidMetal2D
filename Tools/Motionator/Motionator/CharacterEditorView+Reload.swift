//
//  CharacterEditorView+Reload.swift
//  Motionator
//
//  Created by Matt Casanova on 10/10/26.
//

import AppKit
import MotionatorKit
import SwiftUI

/// Taking changes another program (the agent, a script, a text editor) makes
/// to the open folder. The system's document never notices them (seen
/// 2026-10-10: a coordinated write left it alone), so the window watches the
/// folder itself, reloads the document and then tells the system's document
/// that what is on disk is current, or a later autosave would overwrite it.
extension CharacterEditorView {
    func watch(_ url: URL?) {
        session.watcher = url.map { url in DocumentWatcher(url: url) { diskChanged(at: url) } }
    }

    func diskChanged(at url: URL) {
        let backing = backingDocument(for: url)
        if let backing, backing.hasUnautosavedChanges, (try? document.hasChangedOnDisk(at: url)) == true {
            askAboutConflict(at: url, backing: backing)
        } else {
            reload(from: url, backing: backing)
        }
    }

    /// The AppKit document SwiftUI keeps for this folder, when it is open through one.
    private func backingDocument(for url: URL) -> NSDocument? {
        NSDocumentController.shared.documents.first { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }
    }

    private func reload(from url: URL, backing: NSDocument?) {
        do {
            guard let previous = try document.reloadIfChanged(at: url, undoManager: session.undoManager) else { return }
            session.reconcile(from: previous, to: document.character)
            session.problem = nil
            backing?.fileModificationDate = modificationDate(of: url)
            backing?.updateChangeCount(.changeCleared)
        } catch {
            session.problem = "Could not reload \(url.lastPathComponent): \(error)"
        }
    }

    /// Edits not yet autosaved and a folder someone else wrote: one of them loses.
    private func askAboutConflict(at url: URL, backing: NSDocument) {
        let alert = NSAlert()
        alert.messageText = "\(url.lastPathComponent) changed on disk"
        alert.informativeText = "Another program wrote the folder while this window has edits that are not "
            + "saved yet. Reload drops those edits; Keep Mine writes them over the folder."
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Keep Mine")
        let respond: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn {
                reload(from: url, backing: backing)
            } else {
                backing.fileModificationDate = modificationDate(of: url)
                backing.save(nil)
            }
        }
        if let window = backing.windowForSheet {
            alert.beginSheetModal(for: window, completionHandler: respond)
        } else {
            respond(alert.runModal())
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
