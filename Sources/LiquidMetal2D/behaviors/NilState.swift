/// A no-op ``State`` implementation. All lifecycle methods do nothing.
///
/// Used as the default starting state when no explicit state is provided
/// to ``Behavior/setStartState(startState:)``.
public class NilState: State {
    public init() {}

    public func enter() {}
    public func update(dt: Float) {}
    public func exit() {}
}
