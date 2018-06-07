//
//  VVPlayerManager.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/17.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VVPlayer.h"
#import "VVPlayerSkinProtocol.h"

typedef NS_ENUM(NSUInteger,VVEventType) {
    VVEventTypePlay         = 1,//播放
    VVEventTypePause        = 2,//暂停
    VVEventTypePlayEnd      = 3,//播放结束
    VVEventTypePlayError    = 4,//播放出错
    VVEventTypeReplay       = 5,//重播
    VVEventTypeLoadURL      = 6,//加载URL
    VVEventTypeDestory      = 7,//销毁播放器
};

typedef void(^VVEventEndCall)(BOOL isFullScreen,VVEventType eventType);

@interface VVPlayerCoordinate : NSObject<VVPlayerSkinDelegate>
@property (nonatomic, assign, readonly) CGFloat currentPlayDuration;///<当前的播放时间点
@property (nonatomic, assign, readonly) CGFloat totalDuration;///<视频总时长
@property (nonatomic, assign, readonly) BOOL isHeadphones;///<用户是否戴着耳机

@property (nonatomic, copy) AVLayerVideoGravity videoGravity;///< 视频显示模式

/**
 播放器，使用startWithURLString:内部会生成一个播放器
 */
@property (nonatomic, strong, readwrite) VVPlayer *vvPlayer;///<播放器

/**
 设置播放页面的皮肤，可以自定义皮肤。需要遵守 <VVPlayerSkinProtocol> 协议
 */
@property (nonatomic, strong, readwrite) UIView<VVPlayerSkinProtocol> *skinView;

/**
 设置开始播放时是否静音
 但是，当用户通过物理键改变音量时，该属性会自动变为 NO
 */
@property (nonatomic, assign) BOOL isMuted;///<控制播放器开关

/**
 相对上面的字段（isMuted），静音状态不受音量物理键控制。
 */
@property (nonatomic, assign) BOOL forcedMuted;///<是否强制静音播放 defult:NO

/**
 是否使用全屏页面播放
 */
@property (nonatomic, assign) BOOL fullScreenPlay;///<全屏播放

/**
 预留字段，可以根据该字段修改播放器的交互逻辑
 ... 不同的业务存在不同的交互，不过，交互上面是大同小异
 */
@property (nonatomic, assign) NSInteger sourceType;

/**
 内部处理结束后回调（将事件抛出，便于埋点）
 */
@property (nonatomic, copy) VVEventEndCall eventEndCall; ///<播放事件（end）回调

/**
 根据视频的播放地址， videoId 初始化播放器
 @param URLString 视频地址字符串
 @param sourceId 标记视频资源id
 */
- (void)startWithURLString:(NSString* )URLString sourceId:(NSString* )sourceId;
@property (nonatomic, copy, readonly) NSString *sourceId;///<当前的ID

//MARK: - warning 不使用播放器，必须调用
/**
 销毁播放器，同时会将播放视图从父视图移除
 */
- (void)destoryPlayer;


@end


