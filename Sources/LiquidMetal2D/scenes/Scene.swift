//
//  Scene.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/25/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//


import simd
import MetalMath

public protocol Scene {
    func initialize(sceneMgr: SceneManager, renderer: Renderer, input: InputReader)
    func resume()
    func resize()
    func update(dt: Float)
    func draw()
    func shutdown()
    
    static func build() -> Scene
}


open class DefaultScene: Scene {
    public var sceneMgr: SceneManager!
    public var renderer: Renderer!
    public var input: InputReader!
    public var objects: [GameObj]
    
    public init() {
        objects = [GameObj]()
    }
    
    public func initialize(sceneMgr: SceneManager, renderer: Renderer, input: InputReader) {
        self.sceneMgr = sceneMgr
        self.renderer = renderer
        self.input = input
        
        
        renderer.setCamera(point: simd_float3(0, 0, Camera2D.defaultDistance))
        renderer.setPerspective(fov:  degreeToRadian(getFOV()),
                                aspect: renderer.screenAspect,
                                nearZ: PerspectiveProjection.defaultNearZ,
                                farZ: PerspectiveProjection.defaultFarZ)
    }
    
    func getFOV() -> Float {
        if renderer.screenWidth <= renderer.screenHeight { return PerspectiveProjection.defaultFOV }
        return PerspectiveProjection.defaultFOV / (renderer.screenWidth / renderer.screenHeight)
    }
    
    public func draw() {
        let worldUniforms = TransformUniformData()
        
        renderer.beginPass()
        renderer.usePerspective()
        
        for i in 0..<objects.count {
            let obj = objects[i]
            
            renderer.useTexture(textureId: obj.textureID)
            
            
            worldUniforms.transform.setToTransform2D(
                scale: obj.scale,
                angle: obj.rotation,
                translate: simd_float3(obj.position, obj.zOrder)
            )
            
            renderer.draw(uniforms: worldUniforms)
        }
        
        renderer.endPass()
    }
    
    public func resize() {
        renderer.setPerspective(
            fov: degreeToRadian(getFOV()),
            aspect: renderer.screenAspect,
            nearZ: PerspectiveProjection.defaultNearZ,
            farZ: PerspectiveProjection.defaultFarZ)
    }
    
    public func update(dt: Float) {}
    public func shutdown() { objects.removeAll() }
    public func resume() {}
    public static func build() -> Scene { return DefaultScene() }
    
}

