//
//  OrthographicProjection.swift
//
//
//  Created by Matt Casanova on 3/18/26.
//

public class OrthographicProjection {
    public var left: Float = 0
    public var right: Float = 0
    public var bottom: Float = 0
    public var top: Float = 0
    public var nearZ: Float = 0
    public var farZ: Float = 1

    public init() {
    }

    // swiftlint:disable:next function_parameter_count
    public func set(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) {
        self.left   = left
        self.right  = right
        self.bottom = bottom
        self.top    = top
        self.nearZ  = nearZ
        self.farZ   = farZ
    }

    public func make() -> Mat4 {
        return Mat4.makeOrthographic(
            left: left, right: right, bottom: bottom, top: top,
            nearZ: nearZ, farZ: farZ)
    }
}
