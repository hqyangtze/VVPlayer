//
//  UIView+Geometry.m
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/17.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "UIView+Geometry.h"

@implementation UIView (Geometry)
- (CGFloat)left{
    return self.frame.origin.x;
}
- (void)setLeft:(CGFloat)left{
    CGRect f = self.frame;
    f.origin.x = left;
    self.frame = f;
}

- (CGFloat)right{
    return self.frame.origin.x + self.frame.size.width;
}
- (void)setRight:(CGFloat)right{
    CGRect f = self.frame;
    f.origin.x = right - f.size.width;
    self.frame = f;
}

- (CGFloat)top{
    return self.frame.origin.y;
}
- (void)setTop:(CGFloat)top{
    CGRect f = self.frame;
    f.origin.y = top;
    self.frame = f;
}

- (CGFloat)bottom{
    return self.frame.origin.y + self.frame.size.height;
}
- (void)setBottom:(CGFloat)bottom{
    CGRect f = self.frame;
    f.origin.y = bottom - f.size.height;
    self.frame = f;
}

- (CGFloat)width{
    return self.frame.size.width;
}
- (void)setWidth:(CGFloat)width{
    CGRect f = self.frame;
    f.size.width = width;
    self.frame = f;
}

- (CGFloat)height{
    return self.frame.size.height;
}
- (void)setHeight:(CGFloat)height{
    CGRect f = self.frame;
    f.size.height = height;
    self.frame = f;
}

- (CGFloat)centerX{
    return self.frame.origin.x + self.frame.size.width * 0.5;
}
- (void)setCenterX:(CGFloat)centerX{
    CGRect f = self.frame;
    f.origin.x = centerX - f.size.width * 0.5;
    self.frame = f;
}

- (CGFloat)centerY{
    return self.frame.origin.y + self.frame.size.height * 0.5;
}
- (void)setCenterY:(CGFloat)centerY{
    CGRect f = self.frame;
    f.origin.y = centerY - f.size.height * 0.5;
    self.frame = f;
}

- (CGPoint)origin{
    return self.frame.origin;
}
- (void)setOrigin:(CGPoint)origin{
    CGRect f = self.frame;
    f.origin = origin;
    self.frame = f;
}

- (CGSize)size{
    return self.frame.size;
}
- (void)setSize:(CGSize)size{
    CGRect f = self.frame;
    f.size = size;
    self.frame = f;
}

@end
