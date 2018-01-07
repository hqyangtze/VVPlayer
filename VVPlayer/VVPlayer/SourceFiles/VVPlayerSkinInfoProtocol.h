//
//  VVPlayerSkinInfoProtocol.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/11/8.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//


#ifndef VVPlayerSkinInfoProtocol_h
#define VVPlayerSkinInfoProtocol_h

#import <Foundation/Foundation.h>
@protocol VVPlayerSkinInfoProtocol<NSObject>

@optional

/**
 设置显示的标题
 @param title 标题名称
 */
- (void)setTitle:(NSString* )title;

/**
 设置页面背景
 @param imgString 图片链接
 */
- (void)setBgImageWithURLString:(NSString *)imgString;

@end


#endif /* VVPlayerSkinInfoProtocol_h */
