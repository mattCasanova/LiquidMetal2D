//
//  GameMath.m
//  LiquidMetal
//
//  Created by Matt Casanova on 2/9/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

#import "GameMath.h"

@implementation GameMath

/*! The smallest value between two floats*/
+ (float) epsilon                           { return  0.00001f; }
/*! The value of PI*/
+ (float) pi                                { return 3.14159265358979f; }
/*! The Value of PI / 2*/
+ (float) halfPi                            { return 1.5707963267949f; }
 /*! The value of 2 * PI*/
+ (float) twoPi                             { return 6.28318530717959f; }
/*! The conversion factor of degree to Radian*/
+ (float) toRadianFromDegree:(float) degree { return degree * 0.01745329251994f; }
/*! The conversion factor of radian to degree*/
+ (float) toDegreeFromRadian:(float) radian { return radian * 57.29577951308233f; }

/******************************************************************************/
/*!
  If x is smaller than low, x equals low. If x is larger than high, x equals
  high. Otherwise x is unchanged.
   
  \param value
  The value to clamp.
   
  \param low
  The lowest possible value to clamp to.
   
  \param high
  The highest possible value to clamp to.
   
  \return
  A number between low and high (inclusive).
*/
/******************************************************************************/
+ (float) clampFloat:(float)value betweenLow:(float)low andHigh:(float)high {
    if (value < low)
        return low;
    else if (value > high)
        return high;
    
    return value;
}
/******************************************************************************/
/*!
 If x is lower than low, x is set to high. If x is higher than high, x is
 set to low.  Otherwise x is unchanged.
 
 \param value
 The value to wrap.
 
 \param low
 The lowest possible value to wrap.
 
 \param high
 The highest possible value to wrap.
 
 \return
 A number between low and high (inclusive).
 */
/******************************************************************************/
+ (float) wrapFloat:(float)value betweenLow:(float)low andHigh:(float)high {
    if (value < low)
        return high;
    else if (value > high)
        return low;
    
    return value;
}
/******************************************************************************/
/*!
 Returns the larger value of x and y;
 
 \param x
 The first value to check.
 
 \param y
 The second value to check.
 
 \return
 The larger value of x and y.
 */
/******************************************************************************/
+ (float) maxFloat:(float)x y:(float)y {
    return (x > y) ? x : y;
}
/******************************************************************************/
/*!
 Returns the smaller value of x and y;
 
 \param x
 The first value to check.
 
 \param y
 The second value to check.
 
 \return
 The smaller value of x and y.
 */
/******************************************************************************/
+ (float) minFloat:(float)x y:(float)y {
    return (x < y) ? x : y;
}
/******************************************************************************/
/*!
 Returns true if x is in the range of low and high (inclusive).
 
 \param value
 The number to check.
 
 \param low
 The lowest number in the range.
 
 \param high
 The highest number in the range.
 
 \return
 True if x is in the range, false otherwise.
 */
/******************************************************************************/
+ (bool) isFloatInRange:(float)value betweenLow:(float)low andHigh:(float)high {
    return (value >= low && value <= high);
}
/******************************************************************************/
/*!
 Tests if two variables are equal within an EPSILON value.
 
 \param x
 The first number to check.
 
 \param y
 The second number to check.
 
 \return
 True if the values are equal within EPSILON, false otherwise.
 */
/******************************************************************************/
+ (bool) isFloatEqual:(float)x y:(float)y {
    return (fabsf(x - y) < GameMath.epsilon);
}
/******************************************************************************/
/*!
  If x is smaller than low, x equals low. If x is larger than high, x equals
  high. Otherwise x is unchanged.
   
  \param value
  The value to clamp.
   
  \param low
  The lowest possible value to clamp to.
   
  \param high
  The highest possible value to clamp to.
   
  \return
  A number between low and high (inclusive).
*/
/******************************************************************************/
+ (NSInteger) clampInt:(NSInteger)value betweenLow:(NSInteger)low andHigh:(NSInteger)high {
    if (value < low)
        return low;
    else if (value > high)
        return high;

    return value;
}
/******************************************************************************/
/*!
 If x is lower than low, x is set to high. If x is higher than high, x is
 set to low.  Otherwise x is unchanged.
 
 \param value
 The value to wrap.
 
 \param low
 The lowest possible value to wrap.
 
 \param high
 The highest possible value to wrap.
 
 \return
 A number between low and high (inclusive).
 */
/******************************************************************************/
+ (NSInteger) wrapInt:(NSInteger)value betweenLow:(NSInteger)low andHigh:(NSInteger)high {
    if (value < low)
        return high;
    else if (value > high)
        return low;
    
    return value;
}
/******************************************************************************/
/*!
 Returns the larger value of x and y;
 
 \param x
 The first value to check.
 
 \param y
 The second value to check.
 
 \return
 The larger value of x and y.
 */
/******************************************************************************/
+ (NSInteger) maxInt:(NSInteger)x y:(NSInteger) y {
    return (x > y) ? x : y;
}
/******************************************************************************/
/*!
 Returns the smaller value of x and y;
 
 \param x
 The first value to check.
 
 \param y
 The second value to check.
 
 \return
 The smaller value of x and y.
 */
/******************************************************************************/
+ (NSInteger) minInt:(NSInteger)x y:(NSInteger)y {
    return (x < y) ? x : y;
}
/******************************************************************************/
/*!
 Returns true if x is in the range of low and high (inclusive).
 
 \param value
 The number to check.
 
 \param low
 The lowest number in the range.
 
 \param high
 The highest number in the range.
 
 \return
 True if x is in the range, false otherwise.
 */
/******************************************************************************/
+ (bool) isIntInRange:(NSInteger)value betweenLow:(NSInteger)low andHigh:(NSInteger)high {
    return (value >= low && value <= high);
}
/******************************************************************************/
/*!
 Test if a given integer is a power of two or not. This only works for positive
 non zero numbers.
 
 \param x
 The number to check.
 
 \return
 True if the number is a power of two.  false otherwise.
 */
/******************************************************************************/
+ (bool) isPowerOf2:(NSInteger) x {
    /*make sure it is a positive number
     Then, since a power of two only has one bit turned on, if we subtract 1 and
     then and them together no bits should be turned on.*/
    return ((x > 0) && !(x & (x - 1)));
}
/******************************************************************************/
/*!
 Given a number x.  This function will return the next largest power of two.
 
 \param x
 The number to get the next largest power of two.
 
 \return
 The next largest power of two.
 */
/******************************************************************************/
+ (NSInteger) getNextPowerOf2:(NSInteger) x {
    /*Turn on all of the bits lower than the highest on bit.  Then add one.  It
     will be a power of two.*/
    /*--x;*/
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    ++x;
    return x;
}



@end
