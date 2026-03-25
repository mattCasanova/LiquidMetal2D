public class AABBCollider: Collider, MutableAABB {
    public unowned let parent: GameObj
    public var width: Float
    public var height: Float

    public var center: Vec2 {
        get { parent.position }
        set { parent.position.set(newValue.x, newValue.y) }
    }

    public init(parent: GameObj, width: Float, height: Float) {
        self.parent = parent
        self.width = width
        self.height = height
    }

    public func doesCollideWith(collider: Collider) -> Bool {
        return collider.doesCollideWith(aabbCenter: parent.position, width: width, height: height)
    }

    public func doesCollideWith(point: Vec2) -> Bool {
        return Intersect.pointAABB(point: point, center: parent.position, width: width, height: height)
    }

    public func doesCollideWith(circle: Circle) -> Bool {
        return Intersect.circleAABB(
            circleCenter: circle.center, radius: circle.radius,
            aabbCenter: parent.position, width: width, height: height)
    }

    public func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool {
        return Intersect.pointAABB(
            point: parent.position, center: aabbCenter,
            width: self.width + width, height: self.height + height)
    }
}
