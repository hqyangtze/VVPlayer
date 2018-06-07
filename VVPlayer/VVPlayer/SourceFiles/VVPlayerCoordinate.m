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
    if (self = [super init]) {
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
        [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
        [self skinViewPerformSelectorWithArgs:@selector(showContentLost)];
        return;
    }
    [self _vvDestoryCurrentPlayer];
    self.sourceId = sourceId;
    self.currentURLString = URLString;
    _vvPlayer = [[VVPlayer alloc] initWithURLString:URLString];
    [self _vvConfiguratePlayer];
    [self skinViewPerformSelectorWithArgs:@selector(showLoading)];
    [self addNotificationObservers];
    [self checkNetworkEnrimoentAndToastInfo];
    [self skinViewPerformSelectorWithArgs:@selector(setIsMuted:),(self.isMuted)];
    [self _vvPlayEventEndCallBackWithType:VVEventTypeLoadURL];
}

- (void)play{
    [_vvPlayer play];
    [self skinViewPerformSelectorWithArgs:@selector(showPlayingView)];
    [self _vvPlayEventEndCallBackWithType:VVEventTypePlay];
}

- (void)pause{
    [_vvPlayer pause];
    [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
    [self skinViewPerformSelectorWithArgs:@selector(showPauseView)];
    [self _vvPlayEventEndCallBackWithType:VVEventTypePause];
}

- (void)replay{
    [self skinViewPerformSelectorWithArgs:@selector(setInteractiveEnabled:),NO];
    [self skinViewPerformSelectorWithArgs:@selector(updateProgressValue:videoDuration:),0.0,self.totalDuration];
    [self _vvDestoryCurrentPlayer];
    
    [VVRecordPlayTime removePlayDuration:self.sourceId];
    [self _vvPlayEventEndCallBackWithType:VVEventTypeReplay];
    [self startWithURLString:self.currentURLString sourceId:self.sourceId];
}

- (void)destoryPlayer{
    if (_vvPlayer) {
        [self recordVideoPlayCurrentDuration];
        [self _vvDestoryCurrentPlayer];
        [self resetCoordinateProperts];
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

- (void)_vvDestoryCurrentPlayer{
    if (_vvPlayer) {
        [self pause];
        VVPlayer* p = _vvPlayer;[p destory];
        [self _vvPlayEventEndCallBackWithType:VVEventTypeDestory];
        _vvPlayer = nil;
    }
}

- (void)_vvConfiguratePlayer{
    _vvPlayer.needLastFrame = YES;
    _vvPlayer.delegate = (id<VVPlayerDelegate>)self;
    [_vvPlayer setVideoGravity:_videoGravity];
    _vvPlayer.muted = self.isMuted;
    
    if (self.fullScreenPlay) {
        self.isMuted = NO;
        [_vvPlayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    }
    _vvPlayer.playerView.frame = CGRectMake(0, 0, 160, 90);
    self.playerView = _vvPlayer.playerView;
    if (self.playerView) {
        [self skinViewPerformSelectorWithArgs:@selector(setPlayerView:),self.playerView];
    }
}

//MARK: - VVPlayerDelegate
- (void)getPlayer:(VVPlayer *)player event:(VVPlayEvent)playerEvent{
    if (playerEvent == VVPlayEventPrepareDone) {// 资源第一次加载好
         [self _vvPlayEventPrepareDoneEvent];
    }else if (playerEvent == VVPlayEventReadyToPlay){//资源非第一次加载好
        [self play];
    }else if (playerEvent == VVPlayEventCacheChanged){//缓存发生改变
        [self skinViewPerformSelectorWithArgs:@selector(updateCacheValue:videoDuration:),_vvPlayer.hasLoadedDuration,_vvPlayer.totalDuration];
    }else if (playerEvent == VVPlayEventSeekStart){//开始seek
        if (vv_networkStatus() == VVNetWorkUnable) {
            [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
            [self skinViewPerformSelectorWithArgs:@selector(showPauseView)];
            [self skinViewPerformSelectorWithArgs:@selector(showContentError)];
        }else {
            [self skinViewPerformSelectorWithArgs:@selector(showLoading)];
        }
    }else if (playerEvent == VVPlayEventSeekEnd){//结束seek
        [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
    }else if (playerEvent == VVPlayEventEnd){//播放结束
        [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
        [self skinViewPerformSelectorWithArgs:@selector(showFinishedView)];
        [self _vvPlayEventEndCallBackWithType:VVEventTypePlayEnd];
    }else if (playerEvent == VVPlayEventError){//播放出错
        [self toastErrorViewBaseNetworkEnvironment];
        [self _vvPlayEventEndCallBackWithType:VVEventTypePlayError];
    }
}

- (void)playerProgress:(CGFloat)position duration:(CGFloat)duration{
    self.currentPlayDuration = position;
    self.totalDuration = duration;
    [self skinViewPerformSelectorWithArgs:@selector(updateProgressValue:videoDuration:),position,duration];
}

//MARK: - VVPlayerSkinDelegate
- (void)play:(UIView<VVPlayerSkinProtocol> *)skinView{
    if (_vvPlayer.playStatus == VVPlayStatusFinish) {
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
    [_vvPlayer seekToTime:interval completion:^(BOOL finished) {
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
    [self skinViewPerformSelectorWithArgs:@selector(showLoading)];
    if (vv_networkStatus() == VVNetWorkUnable) {
        dispatch_async_on_main_queue(^{
            [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
            [self skinViewPerformSelectorWithArgs:@selector(showContentError)];
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

//MARK: - Private Function
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
        [self skinViewPerformSelectorWithArgs:@selector(showNotWifiToast)];
        [self pause];
    }
    if (vv_networkStatus() == VVNetWorkUnable) {// 无网络
        [self pause];
        [self skinViewPerformSelectorWithArgs:@selector(showContentError)];
    }
}

- (void)_vvApplicationDidEnterBackgroundEvent:(NSNotification *)notification{
    if (self.fullScreenPlay) {
        [self destoryPlayer];
    }
}

- (void)_vvPlayEventPrepareDoneEvent{
    self.totalDuration = _vvPlayer.totalDuration;
    [self skinViewPerformSelectorWithArgs:@selector(setInteractiveEnabled:),YES];
    [self skinViewPerformSelectorWithArgs:@selector(updateProgressValue:videoDuration:),_vvPlayer.currentPlayTime,self.totalDuration];
    
    long long seekToDuration = [[VVRecordPlayTime playDuration:self.sourceId] longLongValue];
    if (seekToDuration > 0) {
        __weak typeof(self) weakSelf = self;
        [_vvPlayer seekToTime:seekToDuration completion:^(BOOL finished) {
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
    [self skinViewPerformSelectorWithArgs:@selector(hidenLoading)];
    if (vv_networkStatus() == VVNetWorkUnable) {
        [self skinViewPerformSelectorWithArgs:@selector(showContentError)];
    }else{
        [self skinViewPerformSelectorWithArgs:@selector(showContentLost)];
    }
}

- (void)checkNetworkEnrimoentAndToastInfo{
    if (vv_networkStatus() > VVNetWorkWiFi) {
        [self skinViewPerformSelectorWithArgs:@selector(showNotWifiToast)];
    }
}

- (void)resetCoordinateProperts{
    _vvPlayer = nil;
    self.currentURLString = nil;
    self.sourceId = nil;
    self.currentPlayDuration = 0;
    self.totalDuration = 0;
    _playerView = nil;
    self.forcedMuted = NO;
    self.fullScreenPlay = NO;
    self.sourceType = 0;
    self.videoGravity = AVLayerVideoGravityResizeAspect;
    self.eventEndCall = nil;
}

- (void)_vvPlayEventEndCallBackWithType:(VVEventType) eventType{
    id temValue = [self skinViewPerformSelectorWithArgs:@selector(isFullScreen)];
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
                if (_vvPlayer.isPlaying) {
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
        [self skinViewPerformSelectorWithArgs:@selector(setViewDelegate:),self];
        if (self.playerView) {
            [self skinViewPerformSelectorWithArgs:@selector(setPlayerView:),self.playerView];
        }
    }
}

- (void)setIsMuted:(BOOL)isMuted{
    _isMuted = isMuted;
    if (self.forcedMuted) {
        _isMuted = YES;
    }
    
    _vvPlayer.muted = _isMuted;
    [self skinViewPerformSelectorWithArgs:@selector(setIsMuted:),self.isMuted];
}

- (void)setForcedMuted:(BOOL)forcedMuted{
    _forcedMuted = forcedMuted;
    
    if (forcedMuted) {
        self.isMuted = YES;
    }
}

- (void)setVideoGravity:(AVLayerVideoGravity )videoGravity{
    NSArray* options = @[AVLayerVideoGravityResizeAspectFill,AVLayerVideoGravityResizeAspect,AVLayerVideoGravityResize];
    if ([options containsObject:videoGravity] && (_videoGravity != videoGravity)) {
        _videoGravity = videoGravity;
        [_vvPlayer setVideoGravity:videoGravity];
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

//MARK: - Helper Function
- (id)skinViewPerformSelectorWithArgs:(SEL)sel, ...{
    if ([self.skinView conformsToProtocol:@protocol(VVPlayerSkinProtocol)]
        && [self.skinView respondsToSelector:sel]) {
        
        NSMethodSignature * sig = [self.skinView methodSignatureForSelector:sel];
        if (!sig) { [self.skinView doesNotRecognizeSelector:sel]; return nil; }
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        if (!inv) { [self.skinView doesNotRecognizeSelector:sel]; return nil; }
        [inv setTarget:self.skinView];
        [inv setSelector:sel];
        va_list args;
        va_start(args, sel);
        [[self class] vvSetInv:inv withSig:sig andArgs:args];
        va_end(args);
        [inv invoke];
        return [[self class] vvGetReturnFromInv:inv withSig:sig];
    }
    return nil;
}

+ (id)vvGetReturnFromInv:(NSInvocation *)inv withSig:(NSMethodSignature *)sig {
    NSUInteger length = [sig methodReturnLength];
    if (length == 0) return nil;
    
    char *type = (char *)[sig methodReturnType];
    while (*type == 'r' || // const
           *type == 'n' || // in
           *type == 'N' || // inout
           *type == 'o' || // out
           *type == 'O' || // bycopy
           *type == 'R' || // byref
           *type == 'V') { // oneway
        type++; // cutoff useless prefix
    }
    
#define return_with_number(_type_) \
do { \
_type_ ret; \
[inv getReturnValue:&ret]; \
return @(ret); \
} while (0)
    
    switch (*type) {
        case 'v': return nil; // void
        case 'B': return_with_number(bool);
        case 'c': return_with_number(char);
        case 'C': return_with_number(unsigned char);
        case 's': return_with_number(short);
        case 'S': return_with_number(unsigned short);
        case 'i': return_with_number(int);
        case 'I': return_with_number(unsigned int);
        case 'l': return_with_number(int);
        case 'L': return_with_number(unsigned int);
        case 'q': return_with_number(long long);
        case 'Q': return_with_number(unsigned long long);
        case 'f': return_with_number(float);
        case 'd': return_with_number(double);
        case 'D': { // long double
            long double ret;
            [inv getReturnValue:&ret];
            return [NSNumber numberWithDouble:ret];
        };
            
        case '@': { // id
            void *ret;
            [inv getReturnValue:&ret];
            return (__bridge id)(ret);
        };
            
        case '#': { // Class
            Class ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        };
            
        default: { // struct / union / SEL / void* / unknown
            const char *objCType = [sig methodReturnType];
            char *buf = calloc(1, length);
            if (!buf) return nil;
            [inv getReturnValue:buf];
            NSValue *value = [NSValue valueWithBytes:buf objCType:objCType];
            free(buf);
            return value;
        };
    }
#undef return_with_number
}

+ (void)vvSetInv:(NSInvocation *)inv withSig:(NSMethodSignature *)sig andArgs:(va_list)args {
    NSUInteger count = [sig numberOfArguments];
    for (int index = 2; index < count; index++) {
        char *type = (char *)[sig getArgumentTypeAtIndex:index];
        while (*type == 'r' || // const
               *type == 'n' || // in
               *type == 'N' || // inout
               *type == 'o' || // out
               *type == 'O' || // bycopy
               *type == 'R' || // byref
               *type == 'V') { // oneway
            type++; // cutoff useless prefix
        }
        
        BOOL unsupportedType = NO;
        switch (*type) {
            case 'v': // 1: void
            case 'B': // 1: bool
            case 'c': // 1: char / BOOL
            case 'C': // 1: unsigned char
            case 's': // 2: short
            case 'S': // 2: unsigned short
            case 'i': // 4: int / NSInteger(32bit)
            case 'I': // 4: unsigned int / NSUInteger(32bit)
            case 'l': // 4: long(32bit)
            case 'L': // 4: unsigned long(32bit)
            { // 'char' and 'short' will be promoted to 'int'.
                int arg = va_arg(args, int);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'q': // 8: long long / long(64bit) / NSInteger(64bit)
            case 'Q': // 8: unsigned long long / unsigned long(64bit) / NSUInteger(64bit)
            {
                long long arg = va_arg(args, long long);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'f': // 4: float / CGFloat(32bit)
            { // 'float' will be promoted to 'double'.
                double arg = va_arg(args, double);
                float argf = arg;
                [inv setArgument:&argf atIndex:index];
            } break;
                
            case 'd': // 8: double / CGFloat(64bit)
            {
                double arg = va_arg(args, double);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case 'D': // 16: long double
            {
                long double arg = va_arg(args, long double);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '*': // char *
            case '^': // pointer
            {
                void *arg = va_arg(args, void *);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case ':': // SEL
            {
                SEL arg = va_arg(args, SEL);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '#': // Class
            {
                Class arg = va_arg(args, Class);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '@': // id
            {
                id arg = va_arg(args, id);
                [inv setArgument:&arg atIndex:index];
            } break;
                
            case '{': // struct
            {
                if (strcmp(type, @encode(CGPoint)) == 0) {
                    CGPoint arg = va_arg(args, CGPoint);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGSize)) == 0) {
                    CGSize arg = va_arg(args, CGSize);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGRect)) == 0) {
                    CGRect arg = va_arg(args, CGRect);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGVector)) == 0) {
                    CGVector arg = va_arg(args, CGVector);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
                    CGAffineTransform arg = va_arg(args, CGAffineTransform);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(CATransform3D)) == 0) {
                    CATransform3D arg = va_arg(args, CATransform3D);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(NSRange)) == 0) {
                    NSRange arg = va_arg(args, NSRange);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(UIOffset)) == 0) {
                    UIOffset arg = va_arg(args, UIOffset);
                    [inv setArgument:&arg atIndex:index];
                } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
                    UIEdgeInsets arg = va_arg(args, UIEdgeInsets);
                    [inv setArgument:&arg atIndex:index];
                } else {
                    unsupportedType = YES;
                }
            } break;
                
            case '(': // union
            {
                unsupportedType = YES;
            } break;
                
            case '[': // array
            {
                unsupportedType = YES;
            } break;
                
            default: // what?!
            {
                unsupportedType = YES;
            } break;
        }
        
        if (unsupportedType) {
            // Try with some dummy type...
            
            NSUInteger size = 0;
            NSGetSizeAndAlignment(type, &size, NULL);
            
#define case_size(_size_) \
else if (size <= 4 * _size_ ) { \
struct dummy { char tmp[4 * _size_]; }; \
struct dummy arg = va_arg(args, struct dummy); \
[inv setArgument:&arg atIndex:index]; \
}
            if (size == 0) { }
            case_size( 1) case_size( 2) case_size( 3) case_size( 4)
            case_size( 5) case_size( 6) case_size( 7) case_size( 8)
            case_size( 9) case_size(10) case_size(11) case_size(12)
            case_size(13) case_size(14) case_size(15) case_size(16)
            case_size(17) case_size(18) case_size(19) case_size(20)
            case_size(21) case_size(22) case_size(23) case_size(24)
            case_size(25) case_size(26) case_size(27) case_size(28)
            case_size(29) case_size(30) case_size(31) case_size(32)
            case_size(33) case_size(34) case_size(35) case_size(36)
            case_size(37) case_size(38) case_size(39) case_size(40)
            case_size(41) case_size(42) case_size(43) case_size(44)
            case_size(45) case_size(46) case_size(47) case_size(48)
            case_size(49) case_size(50) case_size(51) case_size(52)
            case_size(53) case_size(54) case_size(55) case_size(56)
            case_size(57) case_size(58) case_size(59) case_size(60)
            case_size(61) case_size(62) case_size(63) case_size(64)
            else {
                /*
                 Larger than 256 byte?! I don't want to deal with this stuff up...
                 Ignore this argument.
                 */
                struct dummy {char tmp;};
                for (int i = 0; i < size; i++) va_arg(args, struct dummy);
                NSLog(@"YYKit performSelectorWithArgs unsupported type:%s (%lu bytes)",
                      [sig getArgumentTypeAtIndex:index],(unsigned long)size);
            }
#undef case_size
            
        }
    }
}
@end
