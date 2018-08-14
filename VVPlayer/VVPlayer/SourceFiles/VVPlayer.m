//
//  VVAVPlayer.m
//  VVPlayer
//
//  Created by VVPlayer on 2017/11/25.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "VVPlayer.h"
#import <AVFoundation/AVFoundation.h>

static NSString* const kStatus = @"status";
static NSString* const kLoadedTimeRanges = @"loadedTimeRanges";
static NSString* const kPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";
static NSString* const kPlaybackBufferEmpty = @"playbackBufferEmpty";
static NSString* const kPresentationSize = @"presentationSize";

static CGFloat s_volume  = 0.5;//记录用户设置的音量
static const NSUInteger s_kLoginOffset  = 1;
static const NSUInteger s_kActiveOffset  = 2;

static NSString* s_originCategory = nil;
static NSInteger s_originCategoryOption = 0;
static void _vvSetAudioSession(BOOL end,NSString* category,AVAudioSessionCategoryOptions option){
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (end) {
            NSError* error=nil; BOOL  sucess = NO;
            sucess = [[AVAudioSession sharedInstance] setActive:NO withOptions:1 error:&error];
            if (sucess == NO) {
                NSLog(@"VVPlayer _vvSetAudioSession failed: %@\n", error ? [error localizedDescription] : @"nil");
            }
        }else{
            s_originCategoryOption = [AVAudioSession sharedInstance].categoryOptions;
            s_originCategory = [AVAudioSession sharedInstance].category;
            if (vv_validString(category)) {
                [[AVAudioSession sharedInstance] setCategory:category withOptions:option error:nil];
            }
        }
    });
}
void getAudioSession(NSString* category,AVAudioSessionCategoryOptions option){
    _vvSetAudioSession(NO, category, option);
}

@interface _Inner_VVPlayView : UIView
- (void)setPlayer:(AVPlayer*)player;
- (void)setVideoFillMode:(NSString *)fillMode;
@end

@implementation _Inner_VVPlayView

+ (Class)layerClass{
    return [AVPlayerLayer class];
}

- (AVPlayer*)player{
    return [(AVPlayerLayer*)[self layer] player];
}

- (void)setPlayer:(AVPlayer*)player{
    [(AVPlayerLayer*)[self layer] setPlayer:player];
}

- (void)setVideoFillMode:(NSString *)fillMode{
    AVPlayerLayer *playerLayer = (AVPlayerLayer*)[self layer];
    playerLayer.contentsScale = [UIScreen mainScreen].scale;
    playerLayer.videoGravity = fillMode;
    NSArray* videoGravity = @[AVLayerVideoGravityResizeAspect,AVLayerVideoGravityResizeAspectFill,AVLayerVideoGravityResize];
    NSArray* contentModel = @[@(UIViewContentModeScaleAspectFit),@(UIViewContentModeScaleAspectFill),@(UIViewContentModeScaleToFill)];
    NSInteger index = [videoGravity indexOfObject:fillMode];
    if (index >= 0 && index <= 2) {
        self.contentMode = [(NSNumber*)[contentModel objectAtIndex:index] integerValue];
    }
}

@end

@interface VVPlayer (){
    id _playerPeriodicTimeObserver;
}
@property (nonatomic, strong) NSURL           *assetURL;
@property (nonatomic, strong) AVPlayerItem    *playerItem;
@property (nonatomic, strong) AVPlayer        *player;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (nonatomic, assign) BOOL            hasReadyToPlay;
@property (nonatomic, assign) BOOL            isSeeking;
@property (nonatomic, assign) BOOL            noReadyToPlayWhenWillEnterForeground;
@property (nonatomic, assign) NSInteger       manualPauseCout;//> 手动暂停播放
@property (nonatomic, assign) VVPlayStatus    playStatus; //> 播放状态
@property (nonatomic, assign) NSTimeInterval  startPlayTime;//>开始播放时间(单位秒)
@property (nonatomic, assign) CGFloat         playDuration; //> 播放时长，暂停时不计时
@property (nonatomic, assign) CGFloat         initPlayerDuration;//> 首开时间(单位秒)
@property (nonatomic, strong) NSDate          *periodStartDate;
@property (nonatomic, strong) NSDate          *playerInitBeginDate;
@end

@implementation VVPlayer
@synthesize volume = _volume;
@synthesize muted = _muted;

- (void)dealloc{
    [self destory];
}

- (instancetype)initWithURLString:(NSString *)urlString{
    if (self = [super init]) {
        _assetURL = [NSURL URLWithString:urlString];
        _playStatus = VVPlayStatusUnknow;
        _videoGravity = AVLayerVideoGravityResizeAspect;
        _pauseWhenShowLoginView = YES;
        _pauseWhenAPPResignActive = YES;
        _reversePlaybackEnd = NO;
        _needLastFrame = NO;
        _manualPauseCout = 1;
        _volume = s_volume;
        _rate = 1.0f;
        [self _vvInitPlayerView];
        [self _vvInitPlayer];
        [self _vvAddBusinessogicNotification];
    }
    return self;
}

- (void)play{
    if (_hasReadyToPlay == NO) {
        return;
    }
    if (self.isPlaying || (self.manualPauseCout > 1)) {
        return;
    }
    
    _isPlayEnd = NO;
    _noReadyToPlayWhenWillEnterForeground = NO;
    [_player play];
    self.playStatus = VVPlayStatusPlaying;
    [self startPeriodDateStatistics];
}

- (void)pause{
    if (!self.isPlaying) {
        return;
    }
    [_player.currentItem cancelPendingSeeks];
    [_player pause];
    self.playStatus = VVPlayStatusPause;
    [self endPeriodDateStatistics];
}

- (void)destory{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_player) {
        [self pause];
        [self endPeriodDateStatistics];
        self.playStatus = VVPlayStatusUnknow;
        [self _vvRemovePlayItemObserver];
        [self _vvRemovePlayerTimeObserver];
        [_player replaceCurrentItemWithPlayerItem:nil];
        _videoOutput= nil;
        _player = nil;
        _vvSetAudioSession(YES, s_originCategory,s_originCategoryOption);
    }
}

- (void)seekToTime:(CGFloat)interval completion:(void (^)(BOOL finished))completion{
    if (!_hasReadyToPlay) {
        return;
    }
    self.isSeeking = YES;
    CMTime changedTime = CMTimeMakeWithSeconds(interval, 1);
    __weak typeof (self) weakSelf = self;
    [self.player.currentItem seekToTime:changedTime
                        toleranceBefore:kCMTimeZero
                         toleranceAfter:kCMTimeZero
                      completionHandler:^(BOOL finished) {
        __strong typeof (self) strongSelf = weakSelf;
        dispatch_async_on_main_queue(^{
            if (completion) {
                completion(finished);
            }
            strongSelf.isSeeking = NO;
        });
    }];
}

//MARK: - Player Event
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (_isPlayEnd) {
        return;
    }
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:kStatus]) {
        if ([playerItem status] == AVPlayerItemStatusReadyToPlay) {
            self.playStatus = (self.player.rate == 0.0) ? VVPlayStatusPause:VVPlayStatusPlaying;
            [self currentPlayitemReadyToPlay];
        }else if ([playerItem status] == AVPlayerStatusFailed) {
            NSError* error = playerItem.error;
            NSLog(@"vvPlayer error %@",error.localizedFailureReason);
            self.playStatus = VVPlayStatusFailed;
            _isPlayEnd = NO;
            [self endPeriodDateStatistics];
            [self _vvSendDelegateEvent:VVPlayEventError];
        }else if ([playerItem status] == AVPlayerStatusUnknown) {
            self.playStatus = VVPlayStatusUnknow;
            _isPlayEnd = NO;
            [self endPeriodDateStatistics];
            [self _vvSendDelegateEvent:VVPlayEventUnknow];
        }
    }else if ([keyPath isEqualToString:kLoadedTimeRanges]) {
        [self _vvSendDelegateEvent:VVPlayEventCacheChanged];
    }else if ([keyPath isEqualToString:kPlaybackLikelyToKeepUp]) {
        if (self.manualPauseCout > 1) {
            _player.rate = 0.0;
        }
        self.playStatus = (self.player.rate == 0.0) ? VVPlayStatusPause:VVPlayStatusPlaying;
        [self _vvSendDelegateEvent:VVPlayEventSeekEnd];
    }else if ([keyPath isEqualToString:kPlaybackBufferEmpty]) {
        self.playStatus = VVPlayStatusSeeking;
        [self _vvSendDelegateEvent:VVPlayEventSeekStart];
    }else if([keyPath isEqualToString:kPresentationSize]){
        [self _vvSendDelegateEvent:VVPlayEventPresentationSize];
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)currentPlayitemReadyToPlay{
    if (_hasReadyToPlay == NO) {
        _hasReadyToPlay = YES;
        [self _vvInitScrubberTimer];
        _player.volume = _volume;
        _player.muted = _muted;
        _player.rate = _rate;
        // 结束首开计时
        if (self.playerInitBeginDate) {
            self.initPlayerDuration = [[NSDate date] timeIntervalSinceDate:self.playerInitBeginDate];
            self.playerInitBeginDate = nil;
        }
        // 开始播放时间
        if (self.startPlayTime < 1.0) {
            self.startPlayTime = [[NSDate date] timeIntervalSince1970];
        }
        [self _vvSendDelegateEvent:VVPlayEventPrepareDone];
    }else{
        if (_noReadyToPlayWhenWillEnterForeground) {
            NSLog(@"vvPlayer noReadyToPlayWhenWillEnterForeground");
        }else{
            [self _vvSendDelegateEvent:VVPlayEventReadyToPlay];
        }
    }
}

- (void)n_playerItemDidPlayToEndTimeNotification:(NSNotification *)notification {
    AVPlayerItem* obj = notification.object;
    if ([obj isKindOfClass:[AVPlayerItem class]]) {
        if (obj != _playerItem) {
            return;
        }
    }
    
    _isPlayEnd = YES;
    [self endPeriodDateStatistics];
    _playStatus = VVPlayStatusFinish;
    // 播放完 seek 到开始位置
    if (self.reversePlaybackEnd == YES) {
        [self.player.currentItem seekToTime:kCMTimeZero completionHandler:nil];
    }
    [self _vvSendDelegateEvent:VVPlayEventEnd];
}

- (void)n_playerItemNewAccessLogEntryNotification:(NSNotification *)notification{
    AVPlayerItem* obj = notification.object;
    if ([obj isKindOfClass:[AVPlayerItem class]]) {
        if (obj != _playerItem) {
            return;
        }
    }
    
    AVPlayerItemAccessLog* accessLog = [obj accessLog];
    NSString* accessLogString = [[NSString alloc] initWithData:[accessLog extendedLogData] encoding:[accessLog extendedLogDataStringEncoding]];
    NSLog(@"\n\nAVPlayerItem.accessLogString Begin\n");
    NSLog(@"%@",accessLogString);
    NSLog(@"\nAVPlayerItem.accessLogString End\n\n");
    
    NSArray<AVPlayerItemAccessLogEvent*>* events = [accessLog events];
    [events enumerateObjectsUsingBlock:^(AVPlayerItemAccessLogEvent * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"AVPlayerItem.accessLogEvent: \n %@",[self vvAVPlayerItemAccessLogEventInfo:obj]);
    }];
}

- (void)n_playerItemNewErrorLogEntryNotification:(NSNotification *)notification{
    AVPlayerItem* obj = notification.object;
    if ([obj isKindOfClass:[AVPlayerItem class]]) {
        if (obj != _playerItem) {
            return;
        }
    }
    
    AVPlayerItemErrorLog* errorLog = [obj errorLog];
    NSString* errorLogString = [[NSString alloc] initWithData:[errorLog extendedLogData] encoding:[errorLog extendedLogDataStringEncoding]];
    NSLog(@"\n\nAVPlayerItem.errorLog Begin\n");
    NSLog(@"\n%@",errorLogString);
    NSLog(@"\nAVPlayerItem.errorLog End\n\n");
    
    NSArray<AVPlayerItemErrorLogEvent*>* events = [errorLog events];
    [events enumerateObjectsUsingBlock:^(AVPlayerItemErrorLogEvent * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"AVPlayerItem.errorLogEvent: \n %@",[self vvAVPlayerItemErrorLogEventInfo:obj]);
    }];
}

//MARK: - Getter && Setter
- (CGFloat)totalDuration{
    AVPlayerItem *playerItem = [self.player currentItem];
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return CMTimeGetSeconds([playerItem duration]);
    }
    return 0.0;
}

- (CGFloat)currentPlayTime{
    AVPlayerItem *playerItem = [self.player currentItem];
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return CMTimeGetSeconds([playerItem currentTime]);
    }
    return 0.0;
}

- (BOOL)isPlaying{
    AVPlayerItem *playerItem = [self.player currentItem];
    if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
        return ABS(self.player.rate) > 0.0;
    }
    return NO;
}

- (CGFloat)hasLoadedDuration {
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    CGFloat result = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration);
    return result;
}

- (CGFloat)playDuration{
    if (self.periodStartDate) {
        _playDuration += [[NSDate date] timeIntervalSinceDate:self.periodStartDate];
    }
    return _playDuration;
}

- (CGSize)presentationSize{
    return _playerItem ? _playerItem.presentationSize : CGSizeZero;
}

- (float)volume{
    return _volume;
}
- (void)setVolume:(float)volume{
    s_volume = _volume = volume;
    self.player.volume = volume;
}

- (BOOL)isMuted{
    return _muted;
}
-(void)setMuted:(BOOL)muted{
    _muted = muted;
    self.player.muted = muted;
}

- (void)setRate:(float)rate{
    if (_rate != rate) {
        if (rate < 0.0 || rate > 2.0) {
            return;
        }
        
        _rate = rate;
        if (rate == 0.0) {
            [self pause];
        }else{
            [_player setRate:rate];
        }
    }
}

- (void)setNeedLastFrame:(BOOL)needLastFrame{
    if (_needLastFrame != needLastFrame) {
        _needLastFrame = needLastFrame;
        
        if (_needLastFrame && _playerItem) {
            _videoOutput = [[AVPlayerItemVideoOutput alloc] init];
            [_playerItem addOutput:_videoOutput];
        }else if(_videoOutput && _playerItem){
            [_playerItem removeOutput:_videoOutput];
            _videoOutput = nil;
        }
    }
}

- (void)setVideoGravity:(AVLayerVideoGravity )videoGravity{
    NSArray* options = @[AVLayerVideoGravityResizeAspectFill,AVLayerVideoGravityResizeAspect,AVLayerVideoGravityResize];
    if ([options containsObject:videoGravity] && (_videoGravity != videoGravity)) {
        _videoGravity = videoGravity;
        [(_Inner_VVPlayView*)_playerView setVideoFillMode:videoGravity];
    }
}

//MARK: - Private Function
- (void)_vvInitPlayerView{
    if (_playerView == nil) {
        _playerView = [[_Inner_VVPlayView alloc] initWithFrame:CGRectZero];
        [(_Inner_VVPlayView*)_playerView setVideoFillMode:_videoGravity];
        _playerView.clipsToBounds = YES;
    }
}

- (void)_vvInitPlayer{
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:_assetURL];
    !_playerItem ?: [self _vvRemovePlayItemObserver];
    _playerItem = playerItem;
    [self _vvAddPlayItemObserver];
    
    _player = [[AVPlayer alloc] init];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    _player.volume = _volume;
    _player.muted = _muted;
    _player.rate = _rate;
    [(_Inner_VVPlayView*)_playerView setPlayer:_player];
    [_player replaceCurrentItemWithPlayerItem:_playerItem];
    self.playStatus = VVPlayStatusPreparing;
    
    // 跟随系统优化
    if (@available(iOS 10.0, *)) {
        if([_playerItem respondsToSelector:@selector(setPreferredForwardBufferDuration:)]){
            [_playerItem setPreferredForwardBufferDuration:3.0];
        }
    }
    if (@available(iOS 9.0, *)) {
        if([_playerItem respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]){
            [_playerItem setCanUseNetworkResourcesForLiveStreamingWhilePaused:YES];
        }
    }
    if (@available(iOS 10.0, *)) {
        if ([_player respondsToSelector:@selector(setAutomaticallyWaitsToMinimizeStalling:)]) {
            [_player setAutomaticallyWaitsToMinimizeStalling:YES];
        }
    }
    if (@available(iOS 11.0, *)) {
        if ([_playerItem respondsToSelector:@selector(setVideoApertureMode:)]) {
            _playerItem.videoApertureMode = AVVideoApertureModeProductionAperture;
        }
    }
    
    //开始播放时长计时
    _playDuration = 0.0f;
    [self startPeriodDateStatistics];
    //首开时间开始计时
    self.playerInitBeginDate = [NSDate date];
}

- (void)_vvInitScrubberTimer {
    if (!_playerPeriodicTimeObserver) {
        __weak typeof(self) weakSelf = self;
        _playerPeriodicTimeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1)
                                                                            queue:dispatch_get_main_queue()
                                                                       usingBlock:^(CMTime time) {
                                                                           [weakSelf _vvSendTimeDelegate];
                                                                       }];
    }
}

-(void)_vvRemovePlayerTimeObserver{
    if (_playerPeriodicTimeObserver){
        [_player removeTimeObserver:_playerPeriodicTimeObserver];
        _playerPeriodicTimeObserver = nil;
    }
}

- (void)_vvAddPlayItemObserver {
    [_playerItem addObserver:self forKeyPath:kStatus options:NSKeyValueObservingOptionNew context:nil];// 监听status属性
    [_playerItem addObserver:self forKeyPath:kLoadedTimeRanges options:NSKeyValueObservingOptionNew context:nil];// 监听loadedTimeRanges属性
    [_playerItem addObserver:self forKeyPath:kPlaybackLikelyToKeepUp options:NSKeyValueObservingOptionNew context:nil];// 监听是否可以保持播放
    [_playerItem addObserver:self forKeyPath:kPlaybackBufferEmpty options:NSKeyValueObservingOptionNew context:nil];// 监听缓存区状态
    [_playerItem addObserver:self forKeyPath:kPresentationSize options:NSKeyValueObservingOptionNew context:nil];// 监听presentationSize属性
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(n_playerItemDidPlayToEndTimeNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_playerItemNewAccessLogEntryNotification:) name:AVPlayerItemNewAccessLogEntryNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_playerItemNewErrorLogEntryNotification:) name:AVPlayerItemNewErrorLogEntryNotification object:nil];
}

- (void)_vvRemovePlayItemObserver {
    [_player cancelPendingPrerolls];
    [_playerItem cancelPendingSeeks];
    [_playerItem.asset cancelLoading];
    [_playerItem removeObserver:self forKeyPath:kStatus];
    [_playerItem removeObserver:self forKeyPath:kLoadedTimeRanges];
    [_playerItem removeObserver:self forKeyPath:kPlaybackLikelyToKeepUp];
    [_playerItem removeObserver:self forKeyPath:kPlaybackBufferEmpty];
    [_playerItem removeObserver:self forKeyPath:kPresentationSize];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemNewAccessLogEntryNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemNewErrorLogEntryNotification object:nil];
}

- (void)_vvSendDelegateEvent:(VVPlayEvent)event{
    dispatch_async_on_main_queue(^{
        if (_delegate && [_delegate respondsToSelector:@selector(getPlayer:event:)]) {
            [_delegate getPlayer:self event:event];
        }
    });
}

- (void)_vvSendTimeDelegate {
    if (self.isSeeking == NO && self.isPlayEnd == NO) {
        if (CMTIME_IS_INVALID(_player.currentItem.currentTime) || CMTIME_IS_INVALID(_player.currentItem.duration)) {
            return;
        }
        if (_delegate && [_delegate respondsToSelector:@selector(playerProgress:duration:)]) {
            [_delegate playerProgress:self.currentPlayTime duration:self.totalDuration];
        }
        
        if (vv_systemVersion() >= 9.0 && ABS(self.currentPlayTime - self.totalDuration) <= 2.0) {
            [self getLastFrameVideoImage];
        }
    }
}

//MARK: - BusinessogicNotification
- (void)_vvAddBusinessogicNotification{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvApplicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvApplicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvApplicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvWillPresentLoginViewControllerEvent:) name:kLoginViewControllerWillAppearNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_vvDidDismissLoginViewControllerEvent:) name:kLoginViewControllerDidDisappearNotification object:nil];
}

- (void)_vvApplicationWillResignActive:(NSNotification *)noti{
    if (self.pauseWhenAPPResignActive == YES) {
        if (_player.rate > 0.0 || self.manualPauseCout > 1) {
            [self pause];
            self.manualPauseCout = self.manualPauseCout << s_kActiveOffset;
        }
    }
}

- (void)_vvApplicationDidBecomeActive:(NSNotification *)noti{
    if (self.pauseWhenAPPResignActive == YES) {
        if (_player.rate == 0.0 && self.manualPauseCout > 1) {
            self.manualPauseCout = self.manualPauseCout >> s_kActiveOffset;
            if (self.manualPauseCout == 1) {
                [self play];
            }
        }
    }
}

- (void)_vvApplicationDidEnterBackground:(NSNotification *)noti{
    if (vv_systemVersion() < 9.0 && self.videoOutput) {// iOS8 需要的逻辑
        [self getCurrentVideoImage];
        [self.playerItem removeOutput:self.videoOutput];
        
    }
    /// 从后台唤醒后，第一次的readyToPlay事件不需要发送
    _noReadyToPlayWhenWillEnterForeground = !self.isPlaying;
    [self pause];
}

- (void)_vvApplicationWillEnterForeground:(NSNotification *)noti{
    if (vv_systemVersion() < 9.0 && self.videoOutput) {// iOS8 需要的逻辑
        [self.playerItem addOutput:self.videoOutput];
    }
}

- (void)_vvWillPresentLoginViewControllerEvent:(NSNotification* )notify{
    if (self.pauseWhenShowLoginView == YES) {
        if (_player.rate > 0.0 || self.manualPauseCout > 1) {
            [self pause];
            self.manualPauseCout = self.manualPauseCout << s_kLoginOffset;
        }
    }
}

- (void)_vvDidDismissLoginViewControllerEvent:(NSNotification* )notify{
    if (self.pauseWhenShowLoginView == YES) {
        if (_player.rate == 0.0 && self.manualPauseCout > 1) {
            self.manualPauseCout = self.manualPauseCout >> s_kLoginOffset;
            if (self.manualPauseCout == 1) {
                [self play];
            }
        }
    }
}

//MARK: - 播放计时
- (void)startPeriodDateStatistics{
    [self endPeriodDateStatistics];
    self.periodStartDate = [NSDate date];
}

- (void)endPeriodDateStatistics{
    if (self.periodStartDate) {
        _playDuration += [[NSDate date] timeIntervalSinceDate:self.periodStartDate];
        self.periodStartDate = nil;
    }
}

//MARK: - 获取视频帧
-(void)getCurrentVideoImage{
    @try {
        CMTime itemTime = _player.currentTime;
        [self _vvGetBGImageAtCMTime:itemTime];
    } @catch (NSException *exception) {
        NSLog(@"vvPlayer getCurrentVideoImage %@",exception.reason);
    } @finally {
    }
}

- (void)getLastFrameVideoImage{
    @try {
        CMTime itemTime = CMTimeMakeWithSeconds(self.totalDuration-0.05, 600);
        __weak typeof (self) weakSelf = self;
        if (weakSelf.videoOutput) {
            [weakSelf _vvGetBGImageAtCMTime:itemTime];
        }
    } @catch (NSException *exception) {
        NSLog(@"vvPlayer getLastFrameVideoImage%@",exception.reason);
    } @finally {
    }
}

- (void)_vvGetBGImageAtCMTime:(CMTime)itemTime{
    if ([self.videoOutput hasNewPixelBufferForItemTime:itemTime]) {
        CVPixelBufferRef pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:itemTime itemTimeForDisplay:NULL];
        if (pixelBuffer == NULL) {
            NSLog(@"vvPlayer [AVPlayerItemVideoOutput.instance copyPixelBufferForItemTime:itemTimeForDisplay:] return NULL");
            return;
        }
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CVBufferRelease(pixelBuffer);// no use later
        if (ciImage == nil) {
            NSLog(@"vvPlayer [CIImage imageWithCVPixelBuffer:] return nil");
            return;
        }
        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
        CGRect temRect = CGRectMake(0, 0,CVPixelBufferGetWidth(pixelBuffer),CVPixelBufferGetHeight(pixelBuffer));
        CGImageRef videoImage = [temporaryContext createCGImage:ciImage fromRect:temRect];
        dispatch_async_on_main_queue(^{
            if(videoImage != nil){
                self.playerView.layer.contents = (__bridge id)(videoImage);
                CGImageRelease(videoImage);
            }
        });
    }
}


//MARK: - LOG Method
- (NSDictionary*)vvAVPlayerItemAccessLogEventInfo:(AVPlayerItemAccessLogEvent* )event{
    if (!event || ![event isKindOfClass:[AVPlayerItemAccessLogEvent class]]) {
        return @{};
    }
    
    NSDictionary* dic = @{
                          @"numberOfMediaRequests":@(event.numberOfMediaRequests),
                          @"playbackStartDate":event.playbackStartDate?:@"",
                          @"URI":event.URI?:@"",
                          @"serverAddress":event.serverAddress?:@"",
                          @"numberOfServerAddressChanges":@(event.numberOfServerAddressChanges),
                          @"playbackSessionID":event.playbackSessionID?:@"",
                          @"playbackStartOffset":@(event.playbackStartOffset),
                          @"segmentsDownloadedDuration":@(event.segmentsDownloadedDuration),
                          @"durationWatched":@(event.durationWatched),
                          @"numberOfStalls":@(event.numberOfStalls),
                          @"numberOfBytesTransferred":@(event.numberOfBytesTransferred),
                          @"transferDuration":@(event.transferDuration),
                          @"observedBitrate":@(event.observedBitrate),
                          @"indicatedBitrate":@(event.indicatedBitrate),
                          @"numberOfDroppedVideoFrames":@(event.numberOfDroppedVideoFrames),
                          @"startupTime":@(event.startupTime),
                          @"downloadOverdue":@(event.downloadOverdue),
                          @"observedMaxBitrate":@(event.observedMaxBitrate),
                          @"observedMinBitrate":@(event.observedMinBitrate),
                          @"observedBitrateStandardDeviation":@(event.observedBitrateStandardDeviation),
                          @"playbackType":event.playbackType?:@"",
                          @"mediaRequestsWWAN":@(event.mediaRequestsWWAN),
                          @"switchBitrate":@(event.switchBitrate)
                          };
    
    NSMutableDictionary* temDict = dic.mutableCopy;
    if (@available(iOS 10.0, *)) {
        dic = @{
                @"indicatedAverageBitrate":@(event.indicatedAverageBitrate),
                @"averageVideoBitrate":@(event.averageVideoBitrate),
                @"averageAudioBitrate":@(event.averageAudioBitrate)
                };
        [temDict addEntriesFromDictionary:dic];
    }
    
    return temDict;
}


- (NSDictionary*)vvAVPlayerItemErrorLogEventInfo:(AVPlayerItemErrorLogEvent* )event{
    if (!event || ![event isKindOfClass:[AVPlayerItemErrorLogEvent class]]) {
        return @{};
    }
    
    return @{
             @"date":event.date?:@"",
             @"URI":event.URI?:@"",
             @"serverAddress":event.serverAddress?:@"",
             @"playbackSessionID":event.playbackSessionID?:@"",
             @"errorStatusCode":@(event.errorStatusCode),
             @"errorDomain":event.errorDomain?:@"",
             @"errorComment":event.errorComment?:@""
             };
}

@end

