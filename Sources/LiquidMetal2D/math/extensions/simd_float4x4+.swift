//
//  Mat4+.swift
//
//
//  Created by Matt Casanova on 4/14/20.
//

/// Factory and mutating helpers for building common 2D transformation matrices.
public extension Mat4 {

    // MARK: - Static Methods

    /// Creates a 2D look-at (view) matrix that translates the world opposite to the eye position.
    static func makeLookAt2D(_ eye: Vec3) -> Mat4 {
        // Since this is a 2D only game, I can make some assumptions
        var mtx = Mat4(1)
        mtx[3] = Vec4(-eye, 1)
        mtx[3][0] = 0
        mtx[3][1] = 0
        return mtx
    }

    /// Creates a perspective projection matrix.
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

    /// Creates an orthographic projection matrix. Metal NDC z range is [0, 1].
    static func makeOrthographic(
        left: Float, right: Float, bottom: Float, top: Float,
        nearZ: Float, farZ: Float
    ) -> Mat4 {
        let rl = right - left
        let tb = top - bottom
        let fn = farZ - nearZ
        var mtx = Mat4()
        mtx[0] = Vec4(2 / rl, 0, 0, 0)
        mtx[1] = Vec4(0, 2 / tb, 0, 0)
        mtx[2] = Vec4(0, 0, -1 / fn, 0)
        mtx[3] = Vec4(-(right + left) / rl, -(top + bottom) / tb, -nearZ / fn, 1)
        return mtx
    }

    /// Creates a 2D scale matrix from x and y scale factors.
    static func makeScale2D(_ scale: Vec2) -> Mat4 {
        return Mat4(diagonal: Vec4(lowHalf: scale, highHalf: Vec2(1, 1)))
    }

    /// Creates a 2D translation matrix.
    static func makeTranslate2D(_ translate: Vec3) -> Mat4 {
        var mtx = Mat4(1)
        mtx[3] = Vec4(translate, 1)
        return mtx
    }

    /// Creates a 2D rotation matrix for the given angle in radians.
    static func makeRotate2D(_ angle: Float) -> Mat4 {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        var mtx = Mat4(1)
        mtx[0] = Vec4(cosAngle, sinAngle, 0, 0)
        mtx[1] = Vec4(-sinAngle, cosAngle, 0, 0)
        return mtx
    }

    /// Creates a combined 2D scale-rotate-translate matrix.
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

    /// Sets all elements to zero.
    mutating func setToZero() {
        self = Mat4()
    }

    /// Zeroes the matrix then sets the diagonal to the given values.
    mutating func setDiagonal(_ diagonal: Vec4) {
        setToZero()
        self[0][0] = diagonal.x
        self[1][1] = diagonal.y
        self[2][2] = diagonal.z
        self[3][3] = diagonal.w
    }

    /// Sets this matrix to a 2D look-at (view) matrix for the given eye position.
    mutating func setToLookAt2D(_ eye: Vec3) {
        self[0] = Vec4(1, 0, 0, 0)
        self[1] = Vec4(0, 1, 0, 0)
        self[2] = Vec4(0, 0, 1, 0)
        self[3] = Vec4(-eye.x, -eye.y, -eye.z, 1)
    }

    /// Sets this matrix to a 2D scale matrix.
    mutating func setToScale2D(_ scale: Vec2) {
        setDiagonal(Vec4(lowHalf: scale, highHalf: Vec2(1, 1)))
    }

    /// Sets this matrix to a translation matrix.
    mutating func setToTranslate(_ translate: Vec3) {
        setDiagonal(Vec4(repeating: 1))
        self[3] = Vec4(translate, 1)
    }

    /// Sets this matrix to a 2D rotation matrix for the given angle in radians.
    mutating func setToRotate2D(_ angle: Float) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        setDiagonal(Vec4(repeating: 1))
        self[0] = Vec4(cosAngle, sinAngle, 0, 0)
        self[1] = Vec4(-sinAngle, cosAngle, 0, 0)
    }

    /// Sets this matrix to a combined 2D scale-rotate-translate matrix.
    mutating func setToTransform2D(scale: Vec2, angle: Float, translate: Vec3) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        self[0] = Vec4(scale.x * cosAngle, scale.x * sinAngle, 0, 0)
        self[1] = Vec4(scale.y * -sinAngle, scale.y * cosAngle, 0, 0)
        self[2] = Vec4(0, 0, 1, 0)
        self[3] = Vec4(translate.x, translate.y, translate.z, 1)
    }

    static func multiply(_ matrix: Mat4, _ vector: Vec4) -> Vec4 {
        simd_mul(matrix, vector)
    }
}
