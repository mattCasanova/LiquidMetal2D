/// A no-op ``Behavior`` implementation. Starts with a ``NilState``
/// and does nothing each frame.
///
/// Useful as a placeholder when a game object needs a behavior
/// reference but doesn't have any state logic yet.
public class NilBehavior: Behavior {
    public var current: State!

    public init() {
        setStartState()
    }
}
