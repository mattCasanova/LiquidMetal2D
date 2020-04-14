//
//  File.swift
//  
//
//  Created by Matt Casanova on 3/5/20.
//

class ShaderSources {
  
  static let alphaBlendShader = """

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    packed_float3 position;
    packed_float2 texCoord;
};

struct VertexOut {
    VertexOut(float4 pos, float2 tex): position(pos), texCoord(tex) {}
    
    float4 position [[ position ]];
    float2 texCoord;
};

struct Uniforms {
    float4x4 projectionMatrix;
};

vertex VertexOut basic_vertex(
                              const device VertexIn* verts [[ buffer(0) ]],
                              const device Uniforms& uniforms1 [[ buffer(1) ]],
                              const device Uniforms& uniforms2 [[ buffer(2) ]],
                              unsigned int vid [[ vertex_id ]]){
    
    VertexIn inVert = verts[vid];
    
    float4x4 proj = uniforms1.projectionMatrix;
    float4x4 world = uniforms2.projectionMatrix;
    
    float4 position = proj * world * float4(inVert.position, 1.0);
    return VertexOut(position, inVert.texCoord);
}

fragment half4 basic_fragment(VertexOut interpolated [[ stage_in ]], texture2d<half> tex2D [[ texture(0) ]], sampler sampler2D [[ sampler(0) ]]) {
    return tex2D.sample(sampler2D, interpolated.texCoord);
}

"""
}
  
