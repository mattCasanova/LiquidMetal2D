//
//  PointCollider.swift
//  
//
//  Created by Matt Casanova on 3/23/20.
//

public class PointCollider: Collider {
    private weak var obj: GameObj?

    public init(obj: GameObj) {
        self.obj = obj
    }

    public func doesCollideWith(collider: Collider) -> Bool {
        guard let obj else { return false }
        return collider.doesCollideWith(point: obj.position)
    }

    public func doesCollideWith(point: Vec2) -> Bool {
        guard let obj else { return false }
        return simd_epsilon_equal(lhs: point, rhs: obj.position)
    }

    public func doesCollideWith(circle: Circle) -> Bool {
        guard let obj else { return false }
        return Intersect.pointCircle(point: obj.position, circle: circle)
    }

    public func doesCollideWith(aabbCenter: Vec2, width: Float, height: Float) -> Bool {
        guard let obj else { return false }
        return Intersect.pointAABB(point: obj.position, center: aabbCenter, width: width, height: height)
    }
}
