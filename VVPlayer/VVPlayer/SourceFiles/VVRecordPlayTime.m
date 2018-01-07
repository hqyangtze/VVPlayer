//
//  VVRecordPlayDuration.m
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/25.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#import "VVRecordPlayTime.h"
#import "VVHelper.h"
@interface VVRecordPlayTime()

@end

static NSMutableDictionary* s_recordDict = nil;

@implementation VVRecordPlayTime

+ (NSNumber *)playDuration:(NSString *)sourceId{
    return [s_recordDict objectForKey:sourceId];
}

+ (void)recordPlayDuration:(NSNumber *)currentDuration sourceId:(NSString *)sourceId{
    if (!vv_validString(sourceId)) {
        return;
    }
    if ([currentDuration floatValue] <= 0.0) {
        return;
    }
    
    if (s_recordDict) {
        [s_recordDict setObject:currentDuration forKey:sourceId];
    }else{
        s_recordDict = [NSMutableDictionary dictionary];
        [s_recordDict setObject:currentDuration forKey:sourceId];
    }
}

+ (void)removePlayDuration:(NSString *)sourceId{
    if (vv_validString(sourceId)) {
        [s_recordDict removeObjectForKey:sourceId];
    }
}

+ (void)removeAllRecords{
    if (s_recordDict) {
        [s_recordDict removeAllObjects];
        s_recordDict = nil;
    }
}

@end
