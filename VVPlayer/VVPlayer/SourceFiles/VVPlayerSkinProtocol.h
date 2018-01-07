//
//  VVPlayerSkinProtocol.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/11/5.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#ifndef VVPlayerSkinProtocol_h
#define VVPlayerSkinProtocol_h

#import <Foundation/Foundation.h>
#import "VVPlayerSkinDelegate.h"
#import "VVPlayerSkinInfoProtocol.h"

/**
 页面点击事件回调（可能用于埋点）
 - VVSkinEventPlay: 该枚举值可根据需要进行扩展
 */
typedef NS_ENUM(NSUInteger,VVSkinEvent) {
    VVSkinEventPlay             = 1,//点击播放按钮
    VVSkinEventPause            = 2,//点击暂停按钮
    VVSkinEventEnd              = 3,//显示结束页
    VVSkinEventMuted            = 4,//点击静音按钮
    VVSkinEventFullScreen       = 5,//点击全屏按钮
    VVSkinEventReplay           = 6,//点击重播按钮
    VVSkinEventClose            = 7,//关闭播放页面
    VVSkinEventScrubEnd         = 8,//拖拽进度条结束
};

typedef void(^VVSkinEventBlock)(VVSkinEvent eventType ,id params);

/**
 播放器的皮肤需要遵循这个协议
 */
@protocol VVPlayerSkinProtocol<VVPlayerSkinInfoProtocol>

/**
 需要重写 setPlayerView: 方法，将 playerView 放在皮肤合适的视图层级
 播放器 会将内部的播放视图页面赋值该属性
 */
@property (nonatomic, weak) UIView*  playerView;///< 承载视频的图层

/**
 播放器皮肤上面的事件点击需要通知到 播放器 部分的事件代理
 */
@property (nonatomic, weak) id<VVPlayerSkinDelegate> viewDelegate;///<点击事件代理

/**
 更新播放进度
 @param progress 播放进度值（单位秒）
 @param totalDuration 视频总时长（单位秒）
 */
- (void)updateProgressValue:(CGFloat)progress videoDuration:(CGFloat)totalDuration;

@optional

/**
 事件回调（主要是用来埋点）
 params  事件点击携带的参数（nullable）
 */
@property (nonatomic, copy) VVSkinEventBlock buryDataCall;

/**
 需要重写 setInteractiveEnabled:
 播放器在加载远程资源时，皮肤页面最好不接受点击事件。
 */
@property (nonatomic, assign) BOOL  interactiveEnabled;///< 接受交互事件
@property (nonatomic, assign) BOOL  isMuted;///< 声音开关
@property (nonatomic, assign, readonly) BOOL  isFullScreen;///< 是否全屏播放

/**
 初始化样式页面
 */
- (void)initVideoShow;

/**
 显示视频正在加载控件
 */
- (void)showLoading;

/**
 隐藏视频正在加载控件
 */
- (void)hidenLoading;

/**
 非 wifi 环境，toast
 */
- (void)showNotWifiToast; // should hiden automatic

/**
 内容出错页面
 */
- (void)showContentError;

/**
 内容丢失页面
 */
- (void)showContentLost;

/**
 播放结束页面
 */
- (void)showFinishedView;

/**
 正在播放页面
 */
- (void)showPlayingView;

/**
 暂停页面
 */
- (void)showPauseView;

/**
 更新缓存进度
 @param cache 缓存值（秒）
 @param totalDuration 视频的总时长（秒）
 */
- (void)updateCacheValue:(CGFloat)cache videoDuration:(CGFloat)totalDuration;


@end

#endif /* VVPlayerSkinProtocol_h */
