//
//  VVRecordPlayDuration.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/25.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 记录播放时刻点
@interface VVRecordPlayTime : NSObject

+ (NSNumber* )playDuration:(NSString* )sourceId;
+ (void)recordPlayDuration:(NSNumber* )currentDuration sourceId:(NSString* )sourceId;
+ (void)removePlayDuration:(NSString* )sourceId;
+ (void)removeAllRecords;

@end
