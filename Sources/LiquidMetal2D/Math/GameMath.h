//
//  GameMath.h
//  LiquidMetal
//
//  Created by Matt Casanova on 2/9/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

#ifndef GameMath_h
#define GameMath_h

#import <Foundation/Foundation.h>

@interface GameMath: NSObject


+ (float)     epsilon;
+ (float)     pi;
+ (float)     halfPi;
+ (float)     twoPi;
+ (float)     toRadianFromDegree:(float) degree;
+ (float)     toDegreeFromRadian:(float) radian;

+ (float)     clampFloat:(float)value betweenLow:(float)low andHigh:(float)high;
+ (float)     wrapFloat:(float)value betweenLow:(float)low andHigh:(float)high;
+ (float)     maxFloat:(float)x y:(float)y;
+ (float)     minFloat:(float)x y:(float)y;
+ (bool)      isFloatInRange:(float)value betweenLow:(float)low andHigh:(float)high;
+ (bool)      isFloatEqual:(float)x y:(float)y;

+ (NSInteger) clampInt:(NSInteger)value betweenLow:(NSInteger)low andHigh:(NSInteger)high;
+ (NSInteger) wrapInt:(NSInteger)value betweenLow:(NSInteger)low andHigh:(NSInteger)high;
+ (NSInteger) maxInt:(NSInteger)x y:(NSInteger)y;
+ (NSInteger) minInt:(NSInteger)x y:(NSInteger)y;
+ (bool)      isIntInRange:(NSInteger)value betweenLow:(NSInteger)low andHigh:(NSInteger)high;
+ (bool)      isPowerOf2:(NSInteger) x;

+ (NSInteger) getNextPowerOf2:(NSInteger) x;


@end




#endif /* GameMath_h */
