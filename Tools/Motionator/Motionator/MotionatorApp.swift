//
//  MotionatorApp.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import SwiftUI

/// The app: one document window per character, the viewport in the
/// middle, undo and recents from `DocumentGroup`.
@main
struct MotionatorApp: App {
    var body: some SwiftUI.Scene {
        DocumentGroup(
            newDocument: { CharacterDocument() },
            editor: { configuration in CharacterEditorView(document: configuration.document) })
    }
}
