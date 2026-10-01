import LiquidMetal2D

/// Demo-specific component for collision demo zombie/healer data.
/// Attached to GameObj alongside Behavior and Collider components.
class ZombieDemoComponent: Component {
    unowned let parent: GameObj

    /// Time alive in seconds. Blue/green die after 30s; zombies persist forever.
    var age: Float = 0

    /// For green: cures remaining before dying (starts at 3).
    /// For super zombie: hits needed to cure (starts at 3).
    var charges: Int = 0

    /// Whether this is a super zombie (2x size, requires 3 green hits).
    var isSuper: Bool = false

    init(parent: GameObj) {
        self.parent = parent
    }
}
