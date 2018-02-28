//
//  VVPlayerManager.m
//  vvPlayer
//
//  Created by VVPlayer on 2017/12/17.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "VVPlayerCoordinate.h"
#import "VVPlayer.h"
#import "VVRecordPlayTime.h"

NSString* const KNetworkMonitorTypeChangedNotification = @"KNetworkMonitorTypeChangedNotification";

@interface VVPlayerCoordinate()
@property (nonatomic, strong) UIView    *playerView;///<承载播放页面的视图
@property (nonatomic, copy)   NSString  *currentURLString;///<链接
@property (nonatomic, copy)   NSString  *sourceId;///<当前的文章ID
@property (nonatomic, assign) CGFloat   currentPlayDuration;///<当前的播放时间点
@property (nonatomic, assign) CGFloat   totalDuration;///<视频总时长
@end

@implementation VVPlayerCoordinate
@synthesize skinView = _skinView;

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_vvPlayer) {
        [self destoryPlayer];
    }
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _videoGravity = AVLayerVideoGravityResizeAspectFill;
        _isMuted = NO;
        _forcedMuted = NO;
        _fullScreenPlay = NO;
        _sourceType = 0;
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(_vvOpenVolumeSwitchEvent:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvAudioSessionRouteChangeEvent:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}

- (void)startWithURLString:(NSString* )URLString sourceId:(NSString* )sourceId{
    if (!vv_validString(URLString)) {///链接错误
        [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
        [self skinViewPerformSEL:@selector(showContentLost) params:nil];
        return;
    }
    
    [self _destoryCurrentPlayer];
    self.sourceId = sourceId;
    self.currentURLString = URLString;
    self.vvPlayer = [[VVPlayer alloc] initWithURLString:URLString];
    [self _vvConfiguratePlayer];
    [self skinViewPerformSEL:@selector(showLoading) params:nil];
    [self addNotificationObservers];
    [self checkNetworkEnrimoentAndToastInfo];
    [self skinViewPerformSEL:@selector(setIsMuted:) params:@[@(self.isMuted)]];
    [self _vvSendPlayEventEndEventWithType:VVEventTypeLoadURL];
}

- (void)play{
    [self.vvPlayer play];
    [self skinViewPerformSEL:@selector(showPlayingView) params:nil];
    [self _vvSendPlayEventEndEventWithType:VVEventTypePlay];
}

- (void)pause{
    [self.vvPlayer pause];
    [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
    [self skinViewPerformSEL:@selector(showPauseView) params:nil];
    [self _vvSendPlayEventEndEventWithType:VVEventTypePause];
}

- (void)replay{
    [self skinViewPerformSEL:@selector(setInteractiveEnabled:) params:@[@(NO)]];
    [self skinViewPerformSEL:@selector(updateProgressValue:videoDuration:) params:@[@(0.0),@(self.totalDuration)]];
    [self _destoryCurrentPlayer];
    
    [VVRecordPlayTime removePlayDuration:self.sourceId];
    [self _vvSendPlayEventEndEventWithType:VVEventTypeReplay];
    [self startWithURLString:self.currentURLString sourceId:self.sourceId];
}

- (void)destoryPlayer{
    if (_vvPlayer) {
        [self recordVideoPlayCurrentDuration];
        [self _destoryCurrentPlayer];
        [self resetManagerProperts];
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    }
    [self removePlayerViewFromSuperView];
}

- (void)removePlayerViewFromSuperView{
    if (_skinView) {
        dispatch_async_on_main_queue(^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            self.skinView.hidden = YES;
            [self.skinView removeFromSuperview];
            [CATransaction commit];
            _skinView = nil;
            /// 移除通知
            [self removeNotificationObservers];
        });
    }
}

- (void)_destoryCurrentPlayer{
    if (_vvPlayer) {
        [self pause];
        VVPlayer* p = _vvPlayer;[p destory];
        [self _vvSendPlayEventEndEventWithType:VVEventTypeDestory];
        _vvPlayer = nil;
    }
}

- (void)_vvConfiguratePlayer{
    _vvPlayer.needLastFrame = NO;
    _vvPlayer.delegate = (id<VVPlayerDelegate>)self;
    [_vvPlayer setVideoGravity:_videoGravity];
    _vvPlayer.muted = self.isMuted;
    
    if (self.fullScreenPlay) {
        self.isMuted = NO;
        [_vvPlayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    }
    self.vvPlayer.playerView.frame = CGRectMake(0, 0, 160, 90);
    self.playerView = self.vvPlayer.playerView;
    if (self.playerView) {
        [self skinViewPerformSEL:@selector(setPlayerView:) params:@[self.playerView]];
    }
}

#pragma mark - VVPlayerDelegate
- (void)getPlayer:(VVPlayer *)player event:(VVPlayEvent)playerEvent{
    if (playerEvent == VVPlayEventPrepareDone) {// 资源第一次加载好
         [self _vvPlayEventPrepareDoneEvent];
    }else if (playerEvent == VVPlayEventReadyToPlay){//资源非第一次加载好
        [self play];
    }else if (playerEvent == VVPlayEventCacheChanged){//缓存发生改变
        [self skinViewPerformSEL:@selector(updateCacheValue:videoDuration:)
                          params:@[@(self.vvPlayer.hasLoadedDuration),@(self.vvPlayer.totalDuration)]];
    }else if (playerEvent == VVPlayEventSeekStart){//开始seek
        if (vv_networkStatus() == VVNetWorkUnable) {
            [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
            [self skinViewPerformSEL:@selector(showPauseView) params:nil];
            [self skinViewPerformSEL:@selector(showContentError) params:nil];
        }else {
            [self skinViewPerformSEL:@selector(showLoading) params:nil];
        }
    }else if (playerEvent == VVPlayEventSeekEnd){//结束seek
        [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
    }else if (playerEvent == VVPlayEventEnd){//播放结束
        [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
        [self skinViewPerformSEL:@selector(showFinishedView) params:nil];
        [self _vvSendPlayEventEndEventWithType:VVEventTypePlayEnd];
    }else if (playerEvent == VVPlayEventError){//播放出错
        [self toastErrorViewBaseNetworkEnvironment];
        [self _vvSendPlayEventEndEventWithType:VVEventTypePlayError];
    }
}

- (void)playerProgress:(CGFloat)position duration:(CGFloat)duration{
    self.currentPlayDuration = position;
    self.totalDuration = duration;
    [self skinViewPerformSEL:@selector(updateProgressValue:videoDuration:) params:@[@(position),@(duration)]];
}

#pragma mark - VVPlayerSkinDelegate
- (void)play:(UIView<VVPlayerSkinProtocol> *)skinView{
    if (self.vvPlayer.playStatus == VVPlayStatusFinish) {
        [self replay];
    }else{
        [self play];
    }
}

- (void)pause:(UIView<VVPlayerSkinProtocol> *)skinView{
    [self pause];
}

- (void)seekToTime:(CGFloat)interval skinView:(UIView<VVPlayerSkinProtocol> *)skinView complete:(void (^)(BOOL))complete{
    __weak typeof (self) weakSelf = self;
    [self.vvPlayer seekToTime:interval completion:^(BOOL finished) {
        if (finished) {
            [weakSelf play];
        }
        if (complete) {
            complete(finished);
        }
    }];
}

/// 播放过程中，网络出错，尝试重新加载
- (void)reload:(UIView<VVPlayerSkinProtocol> *)skinView{
    [self skinViewPerformSEL:@selector(showLoading) params:nil];
    if (vv_networkStatus() == VVNetWorkUnable) {
        dispatch_async_on_main_queue(^{
            [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
            [self skinViewPerformSEL:@selector(showContentError) params:nil];
        });
        return;
    }else{
        [self startWithURLString:self.currentURLString sourceId:self.sourceId];
    }
}

/// 重播
- (void)replay:(UIView<VVPlayerSkinProtocol> *)skinView{
    [self replay];
}

- (void)skinView:(UIView<VVPlayerSkinProtocol> *)skinView muted:(BOOL)isMuted{
    self.isMuted = isMuted;
}

- (void)close:(UIView<VVPlayerSkinProtocol> *)skinView{
    [self destoryPlayer];
}

#pragma mark - private function
- (void)addNotificationObservers{
    [self removeNotificationObservers];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvNetwotkReachabilityChanged:) name:KNetworkMonitorTypeChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvApplicationDidEnterBackgroundEvent:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)removeNotificationObservers{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KNetworkMonitorTypeChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)_vvNetwotkReachabilityChanged:(NSNotification *)notification{
    if (vv_networkStatus() > VVNetWorkWiFi) {//非wifi
        [self skinViewPerformSEL:@selector(showNotWifiToast) params:nil];
        [self pause];
    }
    if (vv_networkStatus() == VVNetWorkUnable) {// 无网络
        [self pause];
        [self skinViewPerformSEL:@selector(showContentError) params:nil];
    }
}

- (void)_vvApplicationDidEnterBackgroundEvent:(NSNotification *)notification{
    if (self.fullScreenPlay) {
        [self destoryPlayer];
    }
}

- (void)_vvPlayEventPrepareDoneEvent{
    self.totalDuration = _vvPlayer.totalDuration;
    [self skinViewPerformSEL:@selector(setInteractiveEnabled:) params:@[@(YES)]];
    [self skinViewPerformSEL:@selector(updateProgressValue:videoDuration:)
                       params:@[@(self.vvPlayer.currentPlayTime),@(self.totalDuration)]];
    
    long long seekToDuration = [[VVRecordPlayTime playDuration:self.sourceId] longLongValue];
    if (seekToDuration > 0) {
        __weak typeof(self) weakSelf = self;
        [self.vvPlayer seekToTime:seekToDuration completion:^(BOOL finished) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [VVRecordPlayTime removePlayDuration:strongSelf.sourceId];
            [strongSelf play];
        }];
    }else{
        [self play];
    }
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

- (void)recordVideoPlayCurrentDuration{
    if (_vvPlayer.delegate == (id<VVPlayerDelegate>)self) {
        /// 如果即将结束 暂时不做记录
        if (ABS(self.currentPlayDuration - self.totalDuration) <= 2) {
            return;
        }
        [VVRecordPlayTime recordPlayDuration:@(self.currentPlayDuration) sourceId:self.sourceId];
    }
}

- (void)toastErrorViewBaseNetworkEnvironment{
    [self skinViewPerformSEL:@selector(hidenLoading) params:nil];
    if (vv_networkStatus() == VVNetWorkUnable) {
        [self skinViewPerformSEL:@selector(showContentError) params:nil];
    }else{
        [self skinViewPerformSEL:@selector(showContentLost) params:nil];
    }
}

- (void)checkNetworkEnrimoentAndToastInfo{
    if (vv_networkStatus() > VVNetWorkWiFi) {
        [self skinViewPerformSEL:@selector(showNotWifiToast) params:nil];
    }
}

- (void)resetManagerProperts{
    self.vvPlayer = nil;
    self.currentURLString = nil;
    self.sourceId = nil;
    self.currentPlayDuration = 0;
    self.totalDuration = 0;
    _playerView = nil;
    self.forcedMuted = NO;
    self.fullScreenPlay = NO;
    self.sourceType = 0;
    self.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.eventEndCall = nil;
}

- (void)_vvSendPlayEventEndEventWithType:(VVEventType) eventType{
    id temValue = [self skinViewPerformSEL:@selector(isFullScreen) params:nil];
    BOOL isFullScreenn = temValue ? [temValue boolValue] : NO;
    !self.eventEndCall ? : self.eventEndCall(isFullScreenn,eventType);
}

- (void)_vvOpenVolumeSwitchEvent:(NSNotification* )notify{
    NSString *str1 = [[notify userInfo] objectForKey:@"AVSystemController_AudioCategoryNotificationParameter"];
    NSString *str2 = [[notify userInfo] objectForKey:@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
    dispatch_async_on_main_queue(^{
        if(([str1 isEqualToString:@"Audio/Video"] || [str1 isEqualToString:@"Ringtone"])
           && ([str2 isEqualToString:@"ExplicitVolumeChange"])){
            if([UIApplication sharedApplication].applicationState == UIApplicationStateActive){
                if (self.isMuted) {
                    self.isMuted = NO;
                }
                return;
            }
        }
    });
}

- (void)_vvAudioSessionRouteChangeEvent:(NSNotification* )notify{
    NSDictionary *interuptionDict = notify.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    dispatch_async_on_main_queue(^{
        switch (routeChangeReason) {
            case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
                self.isMuted = NO;
                break;
            case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
                if (self.vvPlayer.isPlaying) {
                    [self pause];
                }
                break;
            case AVAudioSessionRouteChangeReasonCategoryChange:
                break;
        }
    });
}

- (void)setSkinView:(UIView<VVPlayerSkinProtocol> *)skinView{
    if (_skinView != skinView) {
        _skinView = skinView;
        [self skinViewPerformSEL:@selector(setViewDelegate:) params:@[self]];
        if (self.playerView) {
            [self skinViewPerformSEL:@selector(setPlayerView:) params:@[self.playerView]];
        }
    }
}

- (void)setIsMuted:(BOOL)isMuted{
    _isMuted = isMuted;
    if (self.forcedMuted) {
        _isMuted = YES;
    }
    
    _vvPlayer.muted = _isMuted;
    [self skinViewPerformSEL:@selector(setIsMuted:) params:@[@(self.isMuted)]];
}

- (void)setVideoGravity:(AVLayerVideoGravity )videoGravity{
    NSArray* options = @[AVLayerVideoGravityResizeAspectFill,AVLayerVideoGravityResizeAspect,AVLayerVideoGravityResize];
    if ([options containsObject:videoGravity] && (_videoGravity != videoGravity)) {
        _videoGravity = videoGravity;
        [self.vvPlayer setVideoGravity:videoGravity];
    }
}

- (void)setVvPlayer:(VVPlayer *)vvPlayer{
    _vvPlayer = vvPlayer;
    [self _vvConfiguratePlayer];
}

/// 是否处于戴有 🎧
- (BOOL)isHeadphones{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *currentRoute = [audioSession currentRoute];
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        if ([[output portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            return YES;
        }
    }
    return NO;
}

//MARK: - Helper function
- (id)skinViewPerformSEL:(SEL)selector params:(NSArray *)objects{
    if ([self.skinView conformsToProtocol:@protocol(VVPlayerSkinProtocol)]
        && [self.skinView respondsToSelector:selector]) {
        
        NSMethodSignature *signature = [[self.skinView class] instanceMethodSignatureForSelector:selector];
        if (signature == nil) {
            return nil;
        }
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = self.skinView;
        invocation.selector = selector;
        
        NSInteger paramsCount = signature.numberOfArguments - 2; // 除self、_cmd以外的参数个数
        paramsCount = MIN(paramsCount, objects.count);
        for (NSInteger i = 0; i < paramsCount; i++) {
            id object = objects[i];
            
            if ([object isKindOfClass:[NSNull class]]) continue;
            
            NSInteger index = i + 2;
            const char* argumentType = [signature getArgumentTypeAtIndex:index];
            
            if (strcmp(argumentType, "s") == 0) {//short
                short value = [object shortValue];
                [invocation setArgument:&value atIndex:index];
                
            }else if(strcmp(argumentType, "l") == 0) {//long
                long value = [object longValue];
                [invocation setArgument:&value atIndex:index];
                
            }else if(strcmp(argumentType, "q") == 0) {//long long
                long long value = [object longLongValue];
                [invocation setArgument:&value atIndex:index];
                
            }else if(strcmp(argumentType, "f") == 0) {//float
                float value = [object floatValue];
                [invocation setArgument:&value atIndex:index];
                
            }else if(strcmp(argumentType, "d") == 0) {//double
                double value = [object doubleValue];
                [invocation setArgument:&value atIndex:index];
                
            }else if(strcmp(argumentType, "B") == 0) {//BOOL
                BOOL value = [object boolValue];
                [invocation setArgument:&value atIndex:index];
                
            }else if(strcmp(argumentType, "{") == 0) {//struct
                
            }else{
                [invocation setArgument:&object atIndex:index];
            }
        }
        
        [invocation invoke];
        
        id returnValue = nil;
        const char* returnType = signature.methodReturnType;
        
        if (signature.methodReturnLength) {
            if (strcmp(returnType, "s") == 0) {//short
                short value = 0;
                [invocation getReturnValue:&value];
                returnValue = [NSNumber numberWithShort:value];
                
            }else if(strcmp(returnType, "l") == 0) {//long
                long value = 0;
                [invocation getReturnValue:&value];
                returnValue = [NSNumber numberWithLong:value];
                
            }else if(strcmp(returnType, "q") == 0) {//long long
                long long value = 0;
                [invocation getReturnValue:&value];
                returnValue = [NSNumber numberWithLongLong:value];
                
            }else if(strcmp(returnType, "f") == 0) {//float
                float value = 0.0;
                [invocation getReturnValue:&value];
                returnValue = [NSNumber numberWithFloat:value];
                
            }else if(strcmp(returnType, "d") == 0) {//double
                double value = 0.0;
                [invocation getReturnValue:&value];
                returnValue = [NSNumber numberWithDouble:value];
                
            }else if(strcmp(returnType, "B") == 0) {//BOOL
                BOOL value = NO;
                [invocation getReturnValue:&value];
                returnValue = [NSNumber numberWithBool:value];
                
            }else if(strcmp(returnType, "{") == 0) {//struct
                
            }else{
                [invocation getReturnValue:&returnValue];
            }
        }
        
        return returnValue;
    }
    return nil;
}

@end
