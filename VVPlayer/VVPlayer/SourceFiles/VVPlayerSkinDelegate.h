//
//  VVPlayerSkinDelegate.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/11/5.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol VVPlayerSkinProtocol;

#ifndef VVPlayerSkinDelegate_h
#define VVPlayerSkinDelegate_h

@protocol VVPlayerSkinDelegate<NSObject>

/**
 播放
 */
- (void)play:(UIView<VVPlayerSkinProtocol>* )skinView;

/**
 暂停
 */
- (void)pause:(UIView<VVPlayerSkinProtocol>* )skinView;

@optional

/**
 快进或者后退到某个时间节点
 @param interval 时间点
 */
- (void)seekToTime:(CGFloat) interval skinView:(UIView<VVPlayerSkinProtocol>* )skinView complete:(void(^)(BOOL finished)) complete;

/**
 重播
 */
- (void)replay:(UIView<VVPlayerSkinProtocol>* )skinView;

/**
 重新加载
 */
- (void)reload:(UIView<VVPlayerSkinProtocol>* )skinView;

/**
 关闭播放器
 */
- (void)close:(UIView<VVPlayerSkinProtocol> *)skinView;

/**
 设置声音开关
 
 @param isMuted 开关状态
 */
- (void)skinView:(UIView<VVPlayerSkinProtocol>* )skinView muted:(BOOL)isMuted;


@end


#endif /* VVPlayerSkinDelegate_h */
