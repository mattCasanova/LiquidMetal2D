//
//  DocumentWatcher.swift
//  Motionator
//
//  Created by Matt Casanova on 10/10/26.
//

import Foundation
import MotionatorKit

/// Watches a `.character` folder and calls `onChange` a moment after
/// anything in it changes, on the main actor. The folder, its `clips` and
/// `images` folders and every file in them each get a descriptor: a folder's
/// tells when files come, go or are replaced, a file's when it is written in
/// place (a text editor, a script), which the folder's never reports. Every
/// event re-opens them all: a safe save replaces the folder itself, and
/// files appear and go.
@MainActor
final class DocumentWatcher {
    let url: URL
    /// How long to wait after the last event before reporting, so a save
    /// that touches several files reports once.
    let settleDelay: TimeInterval
    private let onChange: () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?

    init(url: URL, settleDelay: TimeInterval = 0.2, onChange: @escaping () -> Void) {
        self.url = url
        self.settleDelay = settleDelay
        self.onChange = onChange
        arm()
    }

    isolated deinit {
        pending?.cancel()
        for source in sources { source.cancel() }
    }

    /// The folders and the files in them, as they are right now.
    private var paths: [String] {
        var paths = [url.path]
        let subfolders = [CharacterFiles.clipsFolder, CharacterFiles.imagesFolder].map(url.appendingPathComponent)
        for folder in [url] + subfolders {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            paths += names.map { folder.appendingPathComponent($0).path }
        }
        return paths
    }

    private func arm() {
        for source in sources { source.cancel() }
        sources = []
        for path in paths {
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename], queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.noteEvent() }
            }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            sources.append(source)
        }
    }

    private func noteEvent() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.settle() }
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: item)
    }

    private func settle() {
        pending = nil
        arm()
        onChange()
    }
}
