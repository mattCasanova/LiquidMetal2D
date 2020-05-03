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

struct VertIn {
    packed_float3 position;
    packed_float2 texCoord;
};

struct VertOut {
    VertOut(float4 pos, float2 tex): position(pos), texCoord(tex) {}
    
    float4 position [[ position ]];
    float2 texCoord;
};

struct ProjectionUniform {
    float4x4 m;
};

struct WorldUniform {
    float4x4 m;
    float4 texTrans;
};

vertex VertOut basic_vertex(const device VertIn* verts [[ buffer(0) ]],
                            const device ProjectionUniform& proj [[ buffer(1) ]],
                            const device WorldUniform& world [[ buffer(2) ]],
                            unsigned int vid [[ vertex_id ]]){
    
    VertIn inVert = verts[vid];

    // Get Texture Coords
    float3x3 texMtx = float3x3(
        float3(world.texTrans.x,                0, 0),
        float3(               0, world.texTrans.y, 0),
        float3(world.texTrans.z, world.texTrans.w, 0));

    float2 texCoord = (texMtx * float3(inVert.texCoord, 1)).xy;

    // Get Position
    float4 position = proj.m * world.m * float4(inVert.position, 1.0);
    return VertOut(position, texCoord);
}

fragment half4 basic_fragment(VertOut interpolated [[ stage_in ]],
                              texture2d<half> tex2D [[ texture(0) ]],
                              sampler sampler2D [[ sampler(0) ]]) {
    return tex2D.sample(sampler2D, interpolated.texCoord);
}

"""
}
  
