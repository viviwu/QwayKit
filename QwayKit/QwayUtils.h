//
//  QwayUtils.h
//  QwayKit
//
//  Created by qway on 16/6/3.
//  Copyright © 2016年 qway. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QwayManager.h"

#define IPAD (QwayManager.runningOnIpad)
#define ANIMATED ([QwayManager.instance lpConfigBoolForKey:@"animations_preference"])
#define LC ([QwayManager getLc])

//+++++++++++++++++++Log

#define LOGV(level, ...) [QwayUtils log:level file:__FILE__ line:__LINE__ format:__VA_ARGS__]
#define LOGD(...) LOGV(ORTP_DEBUG, __VA_ARGS__)
#define LOGI(...) LOGV(ORTP_MESSAGE, __VA_ARGS__)
#define LOGW(...) LOGV(ORTP_WARNING, __VA_ARGS__)
#define LOGE(...) LOGV(ORTP_ERROR, __VA_ARGS__)
#define LOGF(...) LOGV(ORTP_FATAL, __VA_ARGS__)

@interface QwayUtils : NSObject

//+++++++++++++++++++Log
+ (void)log:(OrtpLogLevel)severity file:(const char *)file line:(int)line format:(NSString *)format, ...;
+ (void)enableLogs:(OrtpLogLevel)level;

void linphone_iphone_log_handler(const char *domain, OrtpLogLevel lev, const char *fmt, va_list args);
//==================

+ (BOOL)findAndResignFirstResponder:(UIView*)view;

+ (NSString *)deviceModelIdentifier;

+ (LinphoneAddress *)normalizeSipOrPhoneAddress:(NSString *)addr;

typedef enum {
    LinphoneDateHistoryList,
    LinphoneDateHistoryDetails,
    LinphoneDateChatList,
    LinphoneDateChatBubble,
} LinphoneDateFormat;

+ (NSString *)timeToString:(time_t)time withFormat:(LinphoneDateFormat)format;

+ (BOOL)hasSelfAvatar;
+ (UIImage *)selfAvatar;

+ (NSString *)durationToString:(int)duration;

@end

@interface NSNumber (HumanReadableSize)

- (NSString*)toHumanReadableSize;

@end

@interface NSString (linphoneExt)

- (NSString *)md5;
- (BOOL)containsSubstring:(NSString *)str;


@end



/* Use that macro when you want to invoke a custom initialisation method on your class,
 whatever is using it (xib, source code, etc., tableview cell) */
#define INIT_WITH_COMMON_C                                                                                             \
-(instancetype)init {                                                                                              \
return [[super init] commonInit];                                                                              \
}                                                                                                                  \
-(instancetype)initWithCoder : (NSCoder *)aDecoder {                                                               \
return [[super initWithCoder:aDecoder] commonInit];                                                            \
}                                                                                                                  \
-(instancetype)commonInit

#define INIT_WITH_COMMON_CF                                                                                            \
-(instancetype)initWithFrame : (CGRect)frame {                                                                     \
return [[super initWithFrame:frame] commonInit];                                                               \
}                                                                                                                  \
INIT_WITH_COMMON_C
