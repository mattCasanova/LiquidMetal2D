//
//  Transform2D.h
//  LiquidMetal
//
//  Created by Matt Casanova on 2/8/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//


#ifndef Transform2D_h
#define Transform2D_h

#import <Foundation/Foundation.h>
#import "Vector2D.h"

@interface Transform2D : NSObject 

// Creation Methods
+ (Transform2D* _Nonnull) makePerspective:(float)angleRad aspectRatio:(float)aspect nearZ:(float)nearZ farZ:(float)farZ;
+ (Transform2D* _Nonnull) makeOrtho:(float)left right:(float)right top:(float)top bottom:(float)bottom near:(float)near far:(float)far;
+ (Transform2D* _Nonnull) makeLookAt:(Vector2D* _Nonnull)eye distance:(float)distance;
+ (Transform2D* _Nonnull) makeIdentity;
+ (Transform2D* _Nonnull) makeZero;
+ (Transform2D* _Nonnull) makeTransposeOf:(Transform2D* _Nonnull)transform;
+ (Transform2D* _Nonnull) makeScale:(float)x y:(float)y;
+ (Transform2D* _Nonnull) makeRotateZ:(float)radians;
+ (Transform2D* _Nonnull) makeTranslate:(float)x y:(float)y zOrder:(float)zOrder;
+ (Transform2D* _Nonnull) makeScaleX:(float)scaleX scaleY:(float)scaleY radians:(float)radians transX:(float)transX transY:(float)transY zOrder:(float)zOrder;

 
//Basic Init
- (_Nonnull instancetype)init;
- (_Nonnull instancetype)copy;

- (Transform2D* _Nonnull) setToScale:(float)x y:(float)y;
- (Transform2D* _Nonnull) setToRotateZ:(float)radians;
- (Transform2D* _Nonnull) setToTranslate:(float)x y:(float)y zOrder:(float)zOrder;
- (Transform2D* _Nonnull) setToScaleX:(float)scaleX scaleY:(float)scaleY radians:(float)radians transX:(float)transX transY:(float)transY zOrder:(float)zOrder;

- (Transform2D* _Nonnull) transposeSelf;
- (Transform2D* _Nonnull) scaleSelf:(float)x y:(float)y;
- (Transform2D* _Nonnull) rotateZSelf:(float)radians;
- (Transform2D* _Nonnull) translateSelf:(float)x y:(float)y zOrder:(float)zOrder;
- (Transform2D* _Nonnull) multiplyLeftSelf:(const Transform2D* _Nonnull)transform;
- (Transform2D* _Nonnull) multiplyRightSelf:(const Transform2D* _Nonnull)transform;

- (void* _Nonnull)        raw;
- (void)                  set:(int)row col:(int)col value:(float)value;
- (float)                 get:(int)row col:(int)col;

- (Transform2D* _Nonnull) transpose;
- (Transform2D* _Nonnull) multiplyLeft:(const Transform2D* _Nonnull)transform;
- (Transform2D* _Nonnull) multiplyRight:(const Transform2D* _Nonnull)transform;
@end

#endif /* Transform2D_h */
