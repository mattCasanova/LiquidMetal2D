//
//  AABB.swift
//
//
//  Created by Matt Casanova on 3/18/26.
//

/// Read-only axis-aligned bounding box. Used by Intersect methods
/// which only need to read geometry.
public protocol AABB {
    var center: Vec2 { get }
    var width: Float { get }
    var height: Float { get }
}

/// Mutable axis-aligned bounding box. For types that need to modify
/// their bounds (e.g., an AABBCollider).
public protocol MutableAABB: AABB {
    var center: Vec2 { get set }
    var width: Float { get set }
    var height: Float { get set }
}
