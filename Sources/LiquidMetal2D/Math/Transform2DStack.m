//
//  TransformStack.m
//  LiquidMetal
//
//  Created by Matt Casanova on 2/23/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

#import "Transform2DStack.h"

@interface Transform2DStack()
{
    NSMutableArray<Transform2D*>* m_stack;
}
@end


@implementation Transform2DStack

-(_Nonnull instancetype)init {
    self = [super init];
    if (!self)
        return nil;
        
    m_stack = [[NSMutableArray alloc] initWithCapacity:4];
    
    return self;
}

-(void)dealloc {
    m_stack = nil;
}

-(Transform2D* _Nonnull)top {
    return [m_stack lastObject];
}

-(void)load:(Transform2D* _Nonnull)transform {
    [m_stack removeAllObjects];
    [m_stack addObject:transform];
}

-(void)push:(Transform2D* _Nonnull)transform {
    [m_stack addObject:[transform multiplyLeft:[m_stack lastObject]]];
}


-(void)pop {
    [m_stack removeLastObject];
}

-(void)clear {
    [m_stack removeAllObjects];
}

-(bool)isEmpty {
    return [m_stack count] == 0;
}

@end
