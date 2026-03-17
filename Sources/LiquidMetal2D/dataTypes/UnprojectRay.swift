//
//  UnprojectRay.swift
//
//
//  Created by Matt Casanova on 4/20/20.
//


public struct UnprojectRay {
    public let origin: Vec3
    public let vector: Vec3

    public init(origin: Vec3, vector: Vec3) {
        self.origin = origin
        self.vector = vector
    }

    public func getPoint(forWorldZ z: Float) -> Vec3 {
        return origin + (vector * z)
    }
}
