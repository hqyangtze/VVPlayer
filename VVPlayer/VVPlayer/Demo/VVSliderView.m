//
//  VVSliderView.m
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/1.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "VVSliderView.h"
#import "UIView+Geometry.h"

@interface VVSliderView()
@property (nonatomic, strong) UIView *cacheProgressView;
@property (nonatomic, strong) UIView *sliderBgView;
@property (nonatomic, strong) UIView *slidervalueView;
@end

@implementation VVSliderView

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        [self addSubview:self.sliderBgView];
        [self addSubview:self.cacheProgressView];
        [self addSubview:self.slidervalueView];
        [self sendSubviewToBack:self.sliderBgView];
        [self insertSubview:self.cacheProgressView aboveSubview:self.sliderBgView];
        [self insertSubview:self.slidervalueView aboveSubview:self.cacheProgressView];
        [self setMinimumTrackTintColor:[UIColor clearColor]];
        [self setMaximumTrackTintColor:[UIColor clearColor]];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.sliderBgView.frame = self.bounds;
    self.cacheProgressView.height = self.height;
    self.slidervalueView.height = self.height;
    self.slidervalueView.width = self.width*self.value;
    self.cacheProgressView.width = self.width*self.cacheValue;
}

- (void)setValue:(float)value animated:(BOOL)animated{
    [super setValue:value animated:animated];
    self.slidervalueView.width = self.width*self.value;
}

- (void)setValue:(float)value{
    [super setValue:value];
    self.slidervalueView.width = self.width*self.value;
}

- (void)setCacheValue:(CGFloat )cacheValue{
    _cacheValue = cacheValue;
    self.cacheProgressView.width = self.width*cacheValue;
}

- (UIView *)cacheProgressView{
    if (_cacheProgressView == nil) {
        _cacheProgressView = [UIView new];
        _cacheProgressView.backgroundColor = [UIColor grayColor];
    }
    return _cacheProgressView;
}

- (UIView *)slidervalueView{
    if (_slidervalueView == nil) {
        _slidervalueView = [UIView new];
        _slidervalueView.backgroundColor = [UIColor redColor];
    }
    return _slidervalueView;
}


- (UIView *)sliderBgView{
    if (_sliderBgView == nil) {
        _sliderBgView = [UIView new];
        _sliderBgView.backgroundColor = [UIColor whiteColor];
    }
    return _sliderBgView;
}

@end
