//
//  Vector3D.m
//  LiquidMetal
//
//  Created by Matt Casanova on 2/24/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

#import "Vector3D.h"
#import <GLKit/GLKMath.h>
#import "GameMath.h"

@implementation Vector3D  {
  @private GLKVector3 glkVector3;
}

- (_Nonnull instancetype)init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    
    return self;
}

- (_Nonnull instancetype)copy {
    Vector3D* copy = [[Vector3D alloc] init];
    copy->glkVector3 = self->glkVector3;
    return copy;
}

- (void)                  setX:(float)x {
    glkVector3.x = x;
}
- (void)                  setY:(float)y {
    glkVector3.y = y;
}
- (void)                  setZ:(float)z {
    glkVector3.z = z;
}

- (void)                  setR:(float)r {
    glkVector3.r = r;
}
- (void)                  setG:(float)g {
    glkVector3.g = g;
}
- (void)                  setB:(float)b {
    glkVector3.b = b;
}


- (float)                 r {
    return glkVector3.r;
}
- (float)                 g {
    return glkVector3.g;
}
- (float)                 b {
    return glkVector3.b;
}

- (float)                 x {
    return glkVector3.x;
}
- (float)                 y {
    return glkVector3.y;
}
- (float)                 z {
    return glkVector3.z;
}

- (Vector3D* _Nonnull) linearInterpolateSelfTo:(const Vector3D* _Nonnull)rhs atTime:(float)t {
    glkVector3 = GLKVector3Lerp(glkVector3, rhs->glkVector3, t);
    return self;
}

- (Vector3D* _Nonnull)    linearInterpolateTo:(const Vector3D* _Nonnull)rhs atTime:(float)t {
    return [[self copy] linearInterpolateSelfTo:rhs atTime:t];
}

@end
