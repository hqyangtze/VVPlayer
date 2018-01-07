//
//  VVSkinView.m
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/17.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "VVSkinView.h"
#import "VVSliderView.h"

@interface VVSkinView()
@property (nonatomic, strong) UIActivityIndicatorView* loadView;
@property (nonatomic, strong) VVSliderView* progressView;
@end

@implementation VVSkinView

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        [self addSubview:self.loadView];
        [self addSubview:self.progressView];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.playerView.frame = self.bounds;
    self.loadView.center = self.playerView.center;
}

- (void)setPlayerView:(UIView *)playerView{
    _playerView = playerView;
    
    [self insertSubview:playerView atIndex:0];
}

- (void)setInteractiveEnabled:(BOOL)interactiveEnabled{
    _interactiveEnabled = interactiveEnabled;
    
    self.userInteractionEnabled = interactiveEnabled;
}

- (void)updateProgressValue:(CGFloat)progress videoDuration:(CGFloat)totalDuration{
    if (totalDuration>=1.0 && progress > 0.0) {
        self.progressView.value = (progress/totalDuration);
    }
}

/**
 初始化样式页面
 */
- (void)initVideoShow{
    
}

/**
 显示视频正在加载控件
 */
- (void)showLoading{
    [self.loadView startAnimating];
}

/**
 隐藏视频正在加载控件
 */
- (void)hidenLoading{
    [self.loadView stopAnimating];
}

/**
 非 wifi 环境，toast
 */
- (void)showNotWifiToast{
    
}

/**
 内容出错页面
 */
- (void)showContentError{
    
}

/**
 内容丢失页面
 */
- (void)showContentLost{
    
}

/**
 播放结束页面
 */
- (void)showFinishedView{
    
}

/**
 正在播放页面
 */
- (void)showPlayingView{
    
}

/**
 暂停页面
 */
- (void)showPauseView{
    
}

/**
 更新缓存进度
 @param cache 缓存值（秒）
 @param totalDuration 视频的总时长（秒）
 */
- (void)updateCacheValue:(CGFloat)cache videoDuration:(CGFloat)totalDuration{
    if (totalDuration>=1.0 && cache > 0.0) {
        self.progressView.cacheValue = (cache/totalDuration);
    }
}

- (UIActivityIndicatorView *)loadView{
    if (_loadView == nil) {
        _loadView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _loadView.hidesWhenStopped = YES;
    }
    return _loadView;
}

- (VVSliderView *)progressView{
    if (_progressView == nil) {
        _progressView = [[VVSliderView alloc] initWithFrame:CGRectMake(10, self.bottom-20, self.width-20, 3)];
    }
    return _progressView;
}

@end
