//
//  File.swift
//
//
//  Created by Matt Casanova on 4/14/20.
//

import simd

public extension simd_float4x4 {

    // MARK: - Static Methods

    static func makeLookAt2D(_ eye: simd_float3) -> simd_float4x4 {
        // Since this is a 2D only game, I can make some assumptions
        var mtx = simd_float4x4(1)
        mtx[3] = simd_float4(-eye, 1)
        mtx[3][0] = 0
        mtx[3][1] = 0
        return mtx
    }

    static func makePerspective(fovRadian: Float, aspect: Float, n: Float, f: Float) -> simd_float4x4 {
        let scale: Float = tan(fovRadian * 0.5) * n

        let t = scale
        let r = aspect * scale

        var mtx = simd_float4x4()
        mtx[0] = simd_float4(n / r, 0, 0, 0)
        mtx[1] = simd_float4(0, n / t, 0, 0)
        mtx[2] = simd_float4(0, 0, -1 * (f + n) / (f - n), -1)
        mtx[3] = simd_float4(0, 0, -2 * (f * n) / (f - n), 0)
        return mtx
    }

    static func makeScale2D(_ scale: simd_float2) -> simd_float4x4 {
        return simd_float4x4(diagonal: simd_float4(lowHalf: scale, highHalf: simd_float2(1, 1)))
    }

    static func makeTranslate2D(_ translate: simd_float3) -> simd_float4x4 {
        var mtx = simd_float4x4(1)
        mtx[3] = simd_float4(translate, 1)
        return mtx
    }

    static func makeRotate2D(_ angle: Float) -> simd_float4x4 {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        var mtx = simd_float4x4(1)
        mtx[0] = simd_float4(cosAngle, sinAngle, 0, 0)
        mtx[1] = simd_float4(-sinAngle, cosAngle, 0, 0)
        return mtx
    }

    static func makeTransform2D(scale: simd_float2, angle: Float, translate: simd_float3) -> simd_float4x4 {
        var mtx = simd_float4x4()

        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        mtx[0] = simd_float4(scale.x * cosAngle, scale.x * sinAngle, 0, 0)
        mtx[1] = simd_float4(scale.y * -sinAngle, scale.y * cosAngle, 0, 0)
        mtx[2] = simd_float4(0, 0, 1, 0)
        mtx[3] = simd_float4(translate.x, translate.y, translate.z, 1)
        return mtx
    }

    // MARK: - Mutating Methods

    mutating func setToZero() {
        memset(&self, 0, MemoryLayout<simd_float4x4>.size)
    }

    mutating func setDiagonal(_ diagonal: simd_float4) {
        setToZero()
        self[0][0] = diagonal.x
        self[1][1] = diagonal.y
        self[2][2] = diagonal.z
        self[3][3] = diagonal.w
    }

    mutating func setToLookAt2D(_ eye: simd_float3) {
        self[0] = simd_float4(1, 0, 0, 0)
        self[1] = simd_float4(0, 1, 0, 0)
        self[2] = simd_float4(0, 0, 1, 0)
        self[3] = simd_float4(-eye.x, -eye.y, -eye.z, 1)
    }

    mutating func setToScale2D(_ scale: simd_float2) {
        setDiagonal(simd_float4(lowHalf: scale, highHalf: simd_float2(1, 1)))
    }

    mutating func setToTranslate(_ translate: simd_float3) {
        setDiagonal(simd_float4(repeating: 1))
        self[3] = simd_float4(translate, 1)
    }

    mutating func setToRotate2D(_ angle: Float) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        setDiagonal(simd_float4(repeating: 1))
        self[0] = simd_float4(cosAngle, sinAngle, 0, 0)
        self[1] = simd_float4(-sinAngle, cosAngle, 0, 0)
    }

    mutating func setToTransform2D(scale: simd_float2, angle: Float, translate: simd_float3) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        self[0] = simd_float4(scale.x * cosAngle, scale.x * sinAngle, 0, 0)
        self[1] = simd_float4(scale.y * -sinAngle, scale.y * cosAngle, 0, 0)
        self[2] = simd_float4(0, 0, 1, 0)
        self[3] = simd_float4(translate.x, translate.y, translate.z, 1)
    }
}
