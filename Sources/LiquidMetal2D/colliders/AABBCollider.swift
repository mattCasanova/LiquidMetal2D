//
//  AABBCollider.swift
//
//
//  Created by Matt Casanova on 3/18/26.
//

public class AABBCollider: Collider, MutableAABB {
    private weak var obj: GameObj?
    public var width: Float
    public var height: Float

    public var center: Vec2 {
        get { obj?.position ?? Vec2() }
        set { obj?.position.set(newValue.x, newValue.y) }
    }

    public init(obj: GameObj, width: Float, height: Float) {
        self.obj = obj
        self.width = width
        self.height = height
    }

    public func doesCollideWith(collider: Collider) -> Bool {
        guard let obj else { return false }
        return collider.doesCollideWith(aabbCenter: obj.position, width: width, height: height)
    }

    public func doesCollideWith(point: Vec2) -> Bool {
        guard let obj else { return false }
        return Intersect.pointAABB(point: point, center: obj.position, width: width, height: height)
    }

    public func doesCollideWith(circle: Circle) -> Bool {
        guard let obj else { return false }
        return Intersect.circleAABB(
            circleCenter: circle.center, radius: circle.radius,
            aabbCenter: obj.position, width: width, height: height)
    }

    public func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool {
        guard let obj else { return false }
        return Intersect.pointAABB(
            point: obj.position, center: aabbCenter,
            width: self.width + width, height: self.height + height)
    }
}
