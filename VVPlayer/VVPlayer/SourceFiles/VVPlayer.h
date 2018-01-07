//
//  VVAVPlayer.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/11/25.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VVHelper.h"

/**
 设置音频播放时权限
 @param category AVAudioSessionCategoryPlayback...
 @param option AVAudioSessionCategoryOptions
 */
extern void getAudioSession(NSString* category,AVAudioSessionCategoryOptions option);

typedef NS_ENUM(NSInteger, VVPlayStatus) {
    VVPlayStatusUnknow         = -1,// 还没有可用的 playerItem
    VVPlayStatusPreparing      = 0, // 正在初始化 playerItem
    VVPlayStatusPause          = 1, // 播放器处于暂停状态
    VVPlayStatusPlaying        = 2, // 播放器正在播放视频
    VVPlayStatusSeeking        = 3, // 播放器seeking
    VVPlayStatusFinish         = 4, // 播放结束
    VVPlayStatusFailed         = 5, // 播放失败
};

/*
 enum播放状态
 VVPlayEventPrepareDone 资源加载好可以播放，第一次时；
 VVPlayEventReadyToPlay 资源加载好可以播放，非第一次时；
 资源加载过程中出现错误也会 发送 VVPlayEventError 事件
 */
typedef NS_ENUM(int, VVPlayEvent) {
    VVPlayEventUnknow = 1,        // 未知状态不会调用 状态改变回调方法
    VVPlayEventPrepareDone = 2,   // 准备结束
    VVPlayEventReadyToPlay,       // 准备播放
    VVPlayEventCacheChanged,      // 缓存发生变化
    VVPlayEventSeekStart,         // 开始缓冲
    VVPlayEventSeekEnd,           // 缓冲结束
    VVPlayEventEnd,               // 播放结束
    VVPlayEventError,             // 播放出错
};


@class VVPlayer;
@protocol VVPlayerDelegate <NSObject>

@optional
/*播放器播放状态*/
- (void)getPlayer:(VVPlayer *)player event:(VVPlayEvent)playerEvent;

/*播放器播放时间回调*/// 单位秒
- (void)playerProgress:(CGFloat)position duration:(CGFloat)duration;

@end

@interface VVPlayer : NSObject
@property (nonatomic, strong, readonly) UIView          *playerView;///<没有皮肤的播放页面
@property (nonatomic, assign, readonly) BOOL            isPlaying;///<是否在播放
@property (nonatomic, assign, readonly) BOOL            isPlayEnd;///<是否播放结束
@property (nonatomic, assign, readonly) VVPlayStatus    playStatus; ///<播放状态
@property (nonatomic, assign, readonly) CGFloat         totalDuration;///<视频时长(单位秒)
@property (nonatomic, assign, readonly) CGFloat         currentPlayTime;///<当前播放的时间点(单位秒)
@property (nonatomic, assign, readonly) CGFloat         hasLoadedDuration;///<视频缓冲时长(单位秒)
@property (nonatomic, assign, readonly) NSTimeInterval  startPlayTime;///<资源加载可以播放(时间戳)
@property (nonatomic, assign, readonly) CGFloat         playDuration; ///<播放时长，暂停时不计时(单位秒)
@property (nonatomic, assign, readonly) CGFloat         initPlayerDuration;///<首开时长(单位秒)

/// 播放控制
@property (nonatomic, weak) id <VVPlayerDelegate> delegate;///<播放器代理
@property (nonatomic, assign) float volume; ///<音量（0.0 ~ 1.0）
@property (nonatomic, assign, getter=isMuted) BOOL muted;///<静音
@property (nonatomic, assign) BOOL isEarpiece; ///<是否听筒模式
@property (nonatomic, assign) float rate; ///<播放速度 (0.0 ~ 2.0)

/**
 视频画面显示模式
 */
@property (nonatomic, assign) AVLayerVideoGravity videoGravity;///< 视频显示模式

/**
 播放结束时需要停留在最后一帧 default: NO
 不建议使用 YES,可以设置播放器皮肤默认的背景图来达到同样的效果
 */
@property (nonatomic, assign) BOOL needLastFrame;

/**
 弹出登录框时，是否暂停播放  default: YES
 登录框消失后会恢复之前的播放状态
 */
@property (nonatomic, assign) BOOL pauseWhenLogin;

/**
 当APP rseignActive 是否暂停播放 default: YES
 APP active 时，恢复之前的播放状态
 */
@property (nonatomic, assign) BOOL pauseWhenResignActive;

/**
 播放结束主动 seek: kCMTimeZone
 default: NO
 */
@property (nonatomic, assign) BOOL reversePlaybackEnd;

/**
 初始化播放时，设置播放链接，会自动加载资源
 @param urlString 播放链接
 */
- (instancetype)initWithURLString:(NSString *)urlString;

/**
 * 播放
 */
- (void)play;

/**
 * 暂停
 */
- (void)pause;

/**
 * 销毁
 */
- (void)destory;

/**
 seek
 @param interval seek 位置
 @param completion Block (finished 区分是否 seek成功)
 */
- (void)seekToTime:(CGFloat)interval completion:(void (^)(BOOL finished))completion;


- (instancetype)init __attribute__((unavailable("please use initWithURLString:")));
+ (instancetype)new __attribute__((unavailable("please use initWithURLString:")));

@end

