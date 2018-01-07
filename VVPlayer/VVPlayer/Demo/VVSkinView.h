//
//  VVSkinView.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/17.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VVPlayerSkinProtocol.h"
#import "UIView+Geometry.h"

@interface VVSkinView : UIView<VVPlayerSkinProtocol>

@property (nonatomic, weak) UIView*  playerView;///< 承载视频的图层

/**
 播放器皮肤上面的事件点击需要通知到 播放器 部分的事件代理
 */
@property (nonatomic, weak) id<VVPlayerSkinDelegate> viewDelegate;///<点击事件代理

/**
 需要重写 setInteractiveEnabled:
 播放器在加载远程资源时，皮肤页面最好不接受点击事件。
 */
@property (nonatomic, assign) BOOL  interactiveEnabled;///< 接受交互事件


@end
