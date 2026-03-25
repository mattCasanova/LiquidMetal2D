public class PointCollider: Collider {
    public unowned let parent: GameObj

    public init(parent: GameObj) {
        self.parent = parent
    }

    public func doesCollideWith(collider: Collider) -> Bool {
        return collider.doesCollideWith(point: parent.position)
    }

    public func doesCollideWith(point: Vec2) -> Bool {
        return simd_epsilon_equal(lhs: point, rhs: parent.position)
    }

    public func doesCollideWith(circle: Circle) -> Bool {
        return Intersect.pointCircle(point: parent.position, circle: circle)
    }

    public func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool {
        return Intersect.pointAABB(point: parent.position, center: aabbCenter, width: width, height: height)
    }
}
