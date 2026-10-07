//
//  EditorServices.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import LiquidMetal2D

/// The engine's services plus the document and the session, so the scene
/// can draw what the window edits.
@MainActor
final class EditorServices: SceneServices {
    let renderer: Renderer
    let input: InputReader
    let sceneMgr: SceneManager
    let documents: DocumentIO
    let document: CharacterDocument
    let session: EditorSession

    init(
        renderer: Renderer, input: InputReader, sceneMgr: SceneManager, documents: DocumentIO,
        document: CharacterDocument, session: EditorSession
    ) {
        self.renderer = renderer
        self.input = input
        self.sceneMgr = sceneMgr
        self.documents = documents
        self.document = document
        self.session = session
    }
}
