//
//  Mat4+.swift
//
//
//  Created by Matt Casanova on 4/14/20.
//


public extension Mat4 {

    // MARK: - Static Methods

    static func makeLookAt2D(_ eye: Vec3) -> Mat4 {
        // Since this is a 2D only game, I can make some assumptions
        var mtx = Mat4(1)
        mtx[3] = Vec4(-eye, 1)
        mtx[3][0] = 0
        mtx[3][1] = 0
        return mtx
    }

    static func makePerspective(fovRadian: Float, aspect: Float, n: Float, f: Float) -> Mat4 {
        let scale: Float = tan(fovRadian * 0.5) * n

        let t = scale
        let r = aspect * scale

        var mtx = Mat4()
        mtx[0] = Vec4(n / r, 0, 0, 0)
        mtx[1] = Vec4(0, n / t, 0, 0)
        mtx[2] = Vec4(0, 0, -1 * (f + n) / (f - n), -1)
        mtx[3] = Vec4(0, 0, -2 * (f * n) / (f - n), 0)
        return mtx
    }

    static func makeScale2D(_ scale: Vec2) -> Mat4 {
        return Mat4(diagonal: Vec4(lowHalf: scale, highHalf: Vec2(1, 1)))
    }

    static func makeTranslate2D(_ translate: Vec3) -> Mat4 {
        var mtx = Mat4(1)
        mtx[3] = Vec4(translate, 1)
        return mtx
    }

    static func makeRotate2D(_ angle: Float) -> Mat4 {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        var mtx = Mat4(1)
        mtx[0] = Vec4(cosAngle, sinAngle, 0, 0)
        mtx[1] = Vec4(-sinAngle, cosAngle, 0, 0)
        return mtx
    }

    static func makeTransform2D(scale: Vec2, angle: Float, translate: Vec3) -> Mat4 {
        var mtx = Mat4()

        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        mtx[0] = Vec4(scale.x * cosAngle, scale.x * sinAngle, 0, 0)
        mtx[1] = Vec4(scale.y * -sinAngle, scale.y * cosAngle, 0, 0)
        mtx[2] = Vec4(0, 0, 1, 0)
        mtx[3] = Vec4(translate.x, translate.y, translate.z, 1)
        return mtx
    }

    // MARK: - Mutating Methods

    mutating func setToZero() {
        self = Mat4()
    }

    mutating func setDiagonal(_ diagonal: Vec4) {
        setToZero()
        self[0][0] = diagonal.x
        self[1][1] = diagonal.y
        self[2][2] = diagonal.z
        self[3][3] = diagonal.w
    }

    mutating func setToLookAt2D(_ eye: Vec3) {
        self[0] = Vec4(1, 0, 0, 0)
        self[1] = Vec4(0, 1, 0, 0)
        self[2] = Vec4(0, 0, 1, 0)
        self[3] = Vec4(-eye.x, -eye.y, -eye.z, 1)
    }

    mutating func setToScale2D(_ scale: Vec2) {
        setDiagonal(Vec4(lowHalf: scale, highHalf: Vec2(1, 1)))
    }

    mutating func setToTranslate(_ translate: Vec3) {
        setDiagonal(Vec4(repeating: 1))
        self[3] = Vec4(translate, 1)
    }

    mutating func setToRotate2D(_ angle: Float) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        setDiagonal(Vec4(repeating: 1))
        self[0] = Vec4(cosAngle, sinAngle, 0, 0)
        self[1] = Vec4(-sinAngle, cosAngle, 0, 0)
    }

    mutating func setToTransform2D(scale: Vec2, angle: Float, translate: Vec3) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        self[0] = Vec4(scale.x * cosAngle, scale.x * sinAngle, 0, 0)
        self[1] = Vec4(scale.y * -sinAngle, scale.y * cosAngle, 0, 0)
        self[2] = Vec4(0, 0, 1, 0)
        self[3] = Vec4(translate.x, translate.y, translate.z, 1)
    }
}
