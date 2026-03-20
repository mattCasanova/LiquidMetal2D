//
//  Projection.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 3/20/26.
//

import CoreGraphics

public enum Projection {

    public static func project(
        worldPoint: Vec3, projection: Mat4, viewMatrix: Mat4,
        viewFrame: CGRect, viewBounds: CGRect
    ) -> Vec3 {
        let mvp = projection * viewMatrix
        var clipPoint = Mat4.multiply(mvp, worldPoint.to4D(1))
        clipPoint.w = 1 / clipPoint.w

        clipPoint.x *= clipPoint.w
        clipPoint.y *= clipPoint.w
        clipPoint.z *= clipPoint.w

        let viewX = Float(viewFrame.origin.x)
        let viewY = Float(viewFrame.origin.y)
        let width = Float(viewBounds.width)
        let height = Float(viewBounds.height)

        return Vec3(
            (clipPoint.x * 0.5 + 0.5) * width + viewX,
            (clipPoint.y * 0.5 + 0.5) * height + viewY,
            (1.0 + clipPoint.z) * 0.5
        )
    }

    public static func unproject(
        screenPoint: Vec3, projection: Mat4, viewMatrix: Mat4,
        viewFrame: CGRect, viewBounds: CGRect
    ) -> Vec3 {
        let viewX = Float(viewFrame.origin.x)
        let viewY = Float(viewFrame.origin.y)
        let width = Float(viewBounds.width)
        let height = Float(viewBounds.height)

        let clipPoint = Vec4(
            2 * (screenPoint.x - viewX) / width - 1,
            2 * (screenPoint.y - viewY) / height - 1,
            2 * screenPoint.z - 1,
            1
        )

        let inverseMVP = (projection * viewMatrix).inverse
        var worldPoint = Mat4.multiply(inverseMVP, clipPoint)
        worldPoint.w = 1 / worldPoint.w

        return Vec3(
            worldPoint.x * worldPoint.w,
            worldPoint.y * worldPoint.w * -1,
            worldPoint.z * worldPoint.w
        )
    }

    public static func unprojectRay(
        screenPoint: Vec2, projection: Mat4, viewMatrix: Mat4,
        viewFrame: CGRect, viewBounds: CGRect
    ) -> UnprojectRay {
        let near = unproject(screenPoint: Vec3(screenPoint.x, screenPoint.y, 0),
                             projection: projection, viewMatrix: viewMatrix,
                             viewFrame: viewFrame, viewBounds: viewBounds)
        let far = unproject(screenPoint: Vec3(screenPoint.x, screenPoint.y, 1),
                            projection: projection, viewMatrix: viewMatrix,
                            viewFrame: viewFrame, viewBounds: viewBounds)

        let zMag = abs(far.z - near.z)
        let nearFactor = abs(near.z) / zMag
        let farFactor = abs(far.z) / zMag

        let origin = (near * farFactor) + (far * nearFactor)
        let vector = (near - far) / zMag

        return UnprojectRay(origin: origin, vector: vector)
    }
}
