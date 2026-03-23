//
//  CircleCollider.swift
//
//
//  Created by Matt Casanova on 3/23/20.
//

public class CircleCollider: Collider, MutableCircle {
    private weak var obj: GameObj?
    public var radius: Float

    public var center: Vec2 {
        get { obj?.position ?? Vec2() }
        set { obj?.position.set(newValue.x, newValue.y) }
    }

    public init(obj: GameObj, radius: Float) {
        self.obj = obj
        self.radius = radius
    }

    public func doesCollideWith(collider: Collider) -> Bool {
        return collider.doesCollideWith(circle: self)
    }

    public func doesCollideWith(point: Vec2) -> Bool {
        return Intersect.pointCircle(point: point, circle: self)
    }

    public func doesCollideWith(circle: Circle) -> Bool {
        return Intersect.circleCircle(self, circle)
    }

    public func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool {
        guard let obj else { return false }
        return Intersect.circleAABB(
            circleCenter: obj.position, radius: radius,
            aabbCenter: aabbCenter, width: width, height: height)
    }
}
