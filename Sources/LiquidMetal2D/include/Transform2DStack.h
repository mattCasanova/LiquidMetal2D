//
//  TransformStack.h
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

#ifndef TransformStack_h
#define TransformStack_h

#import <Foundation/Foundation.h>
#import "Transform2D.h"

@interface Transform2DStack: NSObject

-(_Nonnull instancetype)init;
-(void)dealloc;

-(Transform2D* _Nonnull)top;
-(void)load:(Transform2D* _Nonnull)transform;
-(void)push:(Transform2D* _Nonnull)transform;


-(void)pop;
-(void)clear;
-(bool)isEmpty;

@end

#endif /* TransformStack_h */
