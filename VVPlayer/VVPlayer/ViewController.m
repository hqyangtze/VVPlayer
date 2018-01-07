//
//  ViewController.m
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/16.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "ViewController.h"
#import "VVSkinView.h"
#import "VVPlayerCoordinate.h"

@interface ViewController ()
@property (nonatomic, strong) VVSkinView* skinView;
@property (nonatomic, strong) VVPlayerCoordinate* playerCoordinate;
@end

@implementation ViewController

- (void)dealloc{
    [_playerCoordinate destoryPlayer];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.skinView];
    self.playerCoordinate.skinView = self.skinView;
    NSString* testURLString = @"http://video.pearvideo.com/mp4/third/20170829/10342995_110931-hd.mp4";
    [self.playerCoordinate startWithURLString:testURLString sourceId:nil];
    [self.playerCoordinate.vvPlayer setNeedLastFrame:YES];
}

- (VVSkinView *)skinView{
    if (_skinView == nil) {
        _skinView = [[VVSkinView alloc] initWithFrame:CGRectMake(5, 0, self.view.width-10, (self.view.width-10))];
    }
    return _skinView;
}

- (VVPlayerCoordinate *)playerCoordinate{
    if (_playerCoordinate == nil) {
        _playerCoordinate = [[VVPlayerCoordinate alloc] init];
        _playerCoordinate.isMuted = NO;
        _playerCoordinate.videoGravity = AVLayerVideoGravityResizeAspect;
    }
    return _playerCoordinate;
}

@end
