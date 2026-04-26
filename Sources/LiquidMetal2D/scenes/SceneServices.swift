/// The bag of engine-built services every scene receives during
/// ``Scene/initialize(services:)``.
///
/// Apps that want to add their own services (typed `CodableBlobStore<T>`,
/// audio manager, analytics, etc.) declare a sub-protocol and a concrete
/// type that conforms to it, then pass a `buildServices` closure to
/// ``DefaultEngine`` to construct it. Scenes downcast as needed:
///
/// ```swift
/// guard let game = services as? GameServices else {
///     fatalError("MyScene requires GameServices")
/// }
/// ```
@MainActor
public protocol SceneServices: AnyObject {
    var renderer: Renderer { get }
    var input: InputReader { get }
    var sceneMgr: SceneManager { get }
    var documents: DocumentIO { get }
}

/// Default ``SceneServices`` implementation. Used automatically when no
/// `buildServices` closure is provided to ``DefaultEngine``.
@MainActor
public final class DefaultSceneServices: SceneServices {
    public let renderer: Renderer
    public let input: InputReader
    public let sceneMgr: SceneManager
    public let documents: DocumentIO

    public init(
        renderer: Renderer,
        input: InputReader,
        sceneMgr: SceneManager,
        documents: DocumentIO
    ) {
        self.renderer = renderer
        self.input = input
        self.sceneMgr = sceneMgr
        self.documents = documents
    }
}
