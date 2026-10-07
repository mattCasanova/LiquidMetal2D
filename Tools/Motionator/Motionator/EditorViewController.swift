//
//  EditorViewController.swift
//  Motionator
//
//  Created by Matt Casanova on 10/7/26.
//

import AppKit
import LiquidMetal2D

/// Hosts the engine for one document window: one scene, the editor's
/// services, pointer and keyboard on.
final class EditorViewController: LiquidViewController {
    private let document: CharacterDocument
    private let session: EditorSession

    init(document: CharacterDocument, session: EditorSession) {
        self.document = document
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("EditorViewController is built in code; see CharacterEditorView")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let factory = SceneFactory()
        factory.addScene(EditorScene.self)
        let renderer = DefaultRenderer(parentView: view, maxObjects: 2048)
        let document = document
        let session = session
        let engine = DefaultEngine(
            renderer: renderer,
            documents: DocumentIO(presentingVC: self),
            inputDevices: [.pointer, .keyboard],
            pausesWhenInactive: false,
            initialSceneType: EditorSceneType.editor,
            sceneFactory: factory,
            buildServices: { renderer, input, sceneMgr, documents in
                EditorServices(renderer: renderer, input: input, sceneMgr: sceneMgr, documents: documents,
                               document: document, session: session)
            })
        gameEngine = engine
        engine.run()
    }
}

enum EditorSceneType: SceneType {
    case editor
}
