//
//  CircleCollider.swift
//
//
//  Created by Matt Casanova on 3/23/20.
//

public class CircleCollider: Collider, MutableCircle {
    public unowned let parent: GameObj
    public var radius: Float

    public var center: Vec2 {
        get { parent.position }
        set { parent.position.set(newValue.x, newValue.y) }
    }

    public init(parent: GameObj, radius: Float) {
        self.parent = parent
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
        return Intersect.circleAABB(
            circleCenter: parent.position, radius: radius,
            aabbCenter: aabbCenter, width: width, height: height)
    }
}
