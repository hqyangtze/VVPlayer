//
//  VVHelper.h
//  VVPlayer
//
//  Created by VVPlayer on 2017/12/16.
//  Copyright © 2017年 VVPlayer, Inc. All rights reserved.
//

#ifndef VVHelper_h
#define VVHelper_h

#import <UIKit/UIKit.h>
#import <pthread.h>

UIKIT_EXTERN NSString* const KNetworkMonitorTypeChangedNotification;
UIKIT_EXTERN NSString* const kLoginViewControllerWillAppearNotification;
UIKIT_EXTERN NSString* const kLoginViewControllerDidDisappearNotification;

typedef NS_ENUM(NSInteger,VVNetWorkStatus) {
    VVNetWorkUnable,
    VVNetWorkWiFi,
    VVNetWork2G,
    VVNetWork3G,
    VVNetWork4G,
};

/**
 获取网络状态...待实现该方法

 @return 当前的网络状态
 */
static inline VVNetWorkStatus vv_networkStatus(void){
    NSInteger defaultStatus = VVNetWorkWiFi;
    return defaultStatus;
}


static inline BOOL vv_validString(NSString* str){
    if ([str isKindOfClass:[NSString class]] && str.length > 0) {
        return YES;
    }
    return NO;
}

static inline CGFloat vv_systemVersion(void){
    return [[UIDevice currentDevice].systemVersion floatValue];
}

static inline void dispatch_async_on_main_queue(void (^block)(void)) {
    if (pthread_main_np()) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static inline void dispatch_sync_on_main_queue(void (^block)(void)) {
    if (pthread_main_np()) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

#endif /* VVHelper_h */
