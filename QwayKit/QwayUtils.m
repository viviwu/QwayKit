//
//  QwayUtils.m
//  QwayKit
//
//  Created by qway on 16/6/3.
//  Copyright © 2016年 qway. All rights reserved.
//

#import "QwayUtils.h"
 

#import <CommonCrypto/CommonDigest.h>
#import <sys/utsname.h>
#import <AssetsLibrary/ALAsset.h>

#import "QwayUtils.h"
#import "linphone/linphonecore.h"


@implementation QwayUtils


#define FILE_SIZE 17
#define DOMAIN_SIZE 3

+ (NSString *)cacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    BOOL isDir = NO;
    NSError *error;
    // cache directory must be created if not existing
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:&error];
    }
    return cachePath;
}

+ (void)log:(OrtpLogLevel)severity file:(const char *)file line:(int)line format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    const char *utf8str = [str cStringUsingEncoding:NSString.defaultCStringEncoding];
    const char *filename = strchr(file, '/') ? strrchr(file, '/') + 1 : file;
    ortp_log(severity, "(%*s:%-4d) %s", FILE_SIZE, filename + MAX((int)strlen(filename) - FILE_SIZE, 0), line, utf8str);
    va_end(args);
}

+ (void)enableLogs:(OrtpLogLevel)level {
    BOOL enabled = (level >= ORTP_DEBUG && level < ORTP_ERROR);
    linphone_core_set_log_collection_path([self cacheDirectory].UTF8String);
    linphone_core_enable_logs_with_cb(linphone_iphone_log_handler);
    linphone_core_enable_log_collection(enabled);
    if (level == 0) {
        linphone_core_set_log_level(ORTP_FATAL);
        ortp_set_log_level("ios", ORTP_FATAL);
        NSLog(@"I/%s/Disabling all logs", ORTP_LOG_DOMAIN);
    } else {
        NSLog(@"I/%s/Enabling %s logs", ORTP_LOG_DOMAIN, (enabled ? "all" : "application only"));
        linphone_core_set_log_level(level);
        ortp_set_log_level("ios", level == ORTP_DEBUG ? ORTP_DEBUG : ORTP_MESSAGE);
    }
}

#pragma mark - Logs Functions callbacks

void linphone_iphone_log_handler(const char *domain, OrtpLogLevel lev, const char *fmt, va_list args) {
    NSString *format = [[NSString alloc] initWithUTF8String:fmt];
    NSString *formatedString = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *lvl = @"";
    switch (lev) {
        case ORTP_FATAL:
            lvl = @"F";
            break;
        case ORTP_ERROR:
            lvl = @"E";
            break;
        case ORTP_WARNING:
            lvl = @"W";
            break;
        case ORTP_MESSAGE:
            lvl = @"I";
            break;
        case ORTP_DEBUG:
        case ORTP_TRACE:
            lvl = @"D";
            break;
        case ORTP_LOGLEV_END:
            return;
    }
    if (!domain)
        domain = "liblinphone";
    // since \r are interpreted like \n, avoid double new lines when logging network packets (belle-sip)
    // output format is like: I/ios/some logs. We truncate domain to **exactly** DOMAIN_SIZE characters to have
    // fixed-length aligned logs
    NSLog(@"%@/%*.*s/%@", lvl, DOMAIN_SIZE, DOMAIN_SIZE, domain,
          [formatedString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]);
}

//==============================

+ (BOOL)hasSelfAvatar {
    return [NSURL URLWithString:[QwayManager.instance lpConfigStringForKey:@"avatar"]] != nil;
}
+ (UIImage *)selfAvatar {
    NSURL *url = [NSURL URLWithString:[QwayManager.instance lpConfigStringForKey:@"avatar"]];
    __block UIImage *ret = nil;
    if (url) {
        __block NSConditionLock *photoLock = [[NSConditionLock alloc] initWithCondition:1];
        // load avatar synchronously so that we can return UIIMage* directly - since we are
        // only using thumbnail, it must be pretty fast to fetch even without cache.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [QwayManager.instance.photoLibrary assetForURL:url
                                               resultBlock:^(ALAsset *asset) {
                                                   ret = [[UIImage alloc] initWithCGImage:[asset thumbnail]];
                                                   [photoLock lock];
                                                   [photoLock unlockWithCondition:0];
                                               }
                                              failureBlock:^(NSError *error) {
                                                  LOGE(@"Can't read avatar");
                                                  [photoLock lock];
                                                  [photoLock unlockWithCondition:0];
                                              }];
        });
        [photoLock lockWhenCondition:0];
        [photoLock unlock];
    }
    
    if (!ret) {
        ret = [UIImage imageNamed:@"avatar.png"];
    }
    return ret;
}

+ (NSString *)durationToString:(int)duration {
    NSMutableString *result = [[NSMutableString alloc] init];
    if (duration / 3600 > 0) {
        [result appendString:[NSString stringWithFormat:@"%02i:", duration / 3600]];
        duration = duration % 3600;
    }
    return [result stringByAppendingString:[NSString stringWithFormat:@"%02i:%02i", (duration / 60), (duration % 60)]];
}

+ (NSString *)timeToString:(time_t)time withFormat:(LinphoneDateFormat)format {
    NSString *formatstr;
    NSDate *todayDate = [[NSDate alloc] init];
    NSDate *messageDate = (time == 0) ? todayDate : [NSDate dateWithTimeIntervalSince1970:time];
    NSDateComponents *todayComponents =
    [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                    fromDate:todayDate];
    NSDateComponents *dateComponents =
    [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                    fromDate:messageDate];
    BOOL sameYear = (todayComponents.year == dateComponents.year);
    BOOL sameMonth = (sameYear && (todayComponents.month == dateComponents.month));
    BOOL sameDay = (sameMonth && (todayComponents.day == dateComponents.day));
    
    switch (format) {
        case LinphoneDateHistoryList:
            if (sameYear) {
                formatstr = NSLocalizedString(@"EEE dd MMMM",
                                              @"Date formatting in History List, for current year (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            } else {
                formatstr = NSLocalizedString(@"EEE dd MMMM yyyy",
                                              @"Date formatting in History List, for previous years (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            }
            break;
        case LinphoneDateHistoryDetails:
            formatstr = NSLocalizedString(@"EEE dd MMM 'at' HH'h'mm", @"Date formatting in History Details (also see "
                                          @"http://cybersam.com/ios-dev/"
                                          @"quick-guide-to-ios-dateformatting)");
            break;
        case LinphoneDateChatList:
            if (sameDay) {
                formatstr = NSLocalizedString(
                                              @"HH:mm", @"Date formatting in Chat List and Conversation bubbles, for current day (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            } else {
                formatstr =
                NSLocalizedString(@"MM/dd", @"Date formatting in Chat List, for all but current day (also see "
                                  @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            }
            break;
        case LinphoneDateChatBubble:
            if (sameDay) {
                formatstr = NSLocalizedString(
                                              @"HH:mm", @"Date formatting in Chat List and Conversation bubbles, for current day (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            } else {
                formatstr = NSLocalizedString(@"MM/dd - HH:mm",
                                              @"Date formatting in Conversation bubbles, for all but current day (also "
                                              @"see http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            }
            break;
    }
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:formatstr];
    return [dateFormatter stringFromDate:messageDate];
}

+ (BOOL)findAndResignFirstResponder:(UIView *)view {
    if (view.isFirstResponder) {
        [view resignFirstResponder];
        return YES;
    }
    for (UIView *subView in view.subviews) {
        if ([QwayUtils findAndResignFirstResponder:subView])
            return YES;
    }
    return NO;
}

+ (void)adjustFontSize:(UIView *)view mult:(float)mult {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        UIFont *font = [label font];
        [label setFont:[UIFont fontWithName:font.fontName size:font.pointSize * mult]];
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *label = (UITextField *)view;
        UIFont *font = [label font];
        [label setFont:[UIFont fontWithName:font.fontName size:font.pointSize * mult]];
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        UIFont *font = button.titleLabel.font;
        [button.titleLabel setFont:[UIFont fontWithName:font.fontName size:font.pointSize * mult]];
    } else {
        for (UIView *subView in [view subviews]) {
            [QwayUtils adjustFontSize:subView mult:mult];
        }
    }
}

+ (void)buttonFixStates:(UIButton *)button {
    // Interface builder lack fixes
    [button setTitle:[button titleForState:UIControlStateSelected]
            forState:(UIControlStateHighlighted | UIControlStateSelected)];
    [button setTitleColor:[button titleColorForState:UIControlStateHighlighted]
                 forState:(UIControlStateHighlighted | UIControlStateSelected)];
    [button setTitle:[button titleForState:UIControlStateSelected]
            forState:(UIControlStateDisabled | UIControlStateSelected)];
    [button setTitleColor:[button titleColorForState:UIControlStateDisabled]
                 forState:(UIControlStateDisabled | UIControlStateSelected)];
}

+ (void)buttonMultiViewAddAttributes:(NSMutableDictionary *)attributes button:(UIButton *)button {
    [QwayUtils addDictEntry:attributes item:[button titleForState:UIControlStateNormal] key:@"title-normal"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleForState:UIControlStateHighlighted]
                            key:@"title-highlighted"];
    [QwayUtils addDictEntry:attributes item:[button titleForState:UIControlStateDisabled] key:@"title-disabled"];
    [QwayUtils addDictEntry:attributes item:[button titleForState:UIControlStateSelected] key:@"title-selected"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleForState:UIControlStateDisabled | UIControlStateHighlighted]
                            key:@"title-disabled-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleForState:UIControlStateSelected | UIControlStateHighlighted]
                            key:@"title-selected-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleForState:UIControlStateSelected | UIControlStateDisabled]
                            key:@"title-selected-disabled"];
    
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateNormal]
                            key:@"title-color-normal"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateHighlighted]
                            key:@"title-color-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateDisabled]
                            key:@"title-color-disabled"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateSelected]
                            key:@"title-color-selected"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateDisabled | UIControlStateHighlighted]
                            key:@"title-color-disabled-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateSelected | UIControlStateHighlighted]
                            key:@"title-color-selected-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button titleColorForState:UIControlStateSelected | UIControlStateDisabled]
                            key:@"title-color-selected-disabled"];
    
    [QwayUtils addDictEntry:attributes item:NSStringFromUIEdgeInsets([button titleEdgeInsets]) key:@"title-edge"];
    [QwayUtils addDictEntry:attributes
                           item:NSStringFromUIEdgeInsets([button contentEdgeInsets])
                            key:@"content-edge"];
    [QwayUtils addDictEntry:attributes item:NSStringFromUIEdgeInsets([button imageEdgeInsets]) key:@"image-edge"];
    
    [QwayUtils addDictEntry:attributes item:[button imageForState:UIControlStateNormal] key:@"image-normal"];
    [QwayUtils addDictEntry:attributes
                           item:[button imageForState:UIControlStateHighlighted]
                            key:@"image-highlighted"];
    [QwayUtils addDictEntry:attributes item:[button imageForState:UIControlStateDisabled] key:@"image-disabled"];
    [QwayUtils addDictEntry:attributes item:[button imageForState:UIControlStateSelected] key:@"image-selected"];
    [QwayUtils addDictEntry:attributes
                           item:[button imageForState:UIControlStateDisabled | UIControlStateHighlighted]
                            key:@"image-disabled-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button imageForState:UIControlStateSelected | UIControlStateHighlighted]
                            key:@"image-selected-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button imageForState:UIControlStateSelected | UIControlStateDisabled]
                            key:@"image-selected-disabled"];
    
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateNormal]
                            key:@"background-normal"];
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateHighlighted]
                            key:@"background-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateDisabled]
                            key:@"background-disabled"];
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateSelected]
                            key:@"background-selected"];
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateDisabled | UIControlStateHighlighted]
                            key:@"background-disabled-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateSelected | UIControlStateHighlighted]
                            key:@"background-selected-highlighted"];
    [QwayUtils addDictEntry:attributes
                           item:[button backgroundImageForState:UIControlStateSelected | UIControlStateDisabled]
                            key:@"background-selected-disabled"];
}

+ (void)buttonMultiViewApplyAttributes:(NSDictionary *)attributes button:(UIButton *)button {
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-normal"] forState:UIControlStateNormal];
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-highlighted"]
            forState:UIControlStateHighlighted];
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-disabled"] forState:UIControlStateDisabled];
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-selected"] forState:UIControlStateSelected];
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-disabled-highlighted"]
            forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-selected-highlighted"]
            forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setTitle:[QwayUtils getDictEntry:attributes key:@"title-selected-disabled"]
            forState:UIControlStateSelected | UIControlStateDisabled];
    
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-normal"]
                 forState:UIControlStateNormal];
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-highlighted"]
                 forState:UIControlStateHighlighted];
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-disabled"]
                 forState:UIControlStateDisabled];
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-selected"]
                 forState:UIControlStateSelected];
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-disabled-highlighted"]
                 forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-selected-highlighted"]
                 forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setTitleColor:[QwayUtils getDictEntry:attributes key:@"title-color-selected-disabled"]
                 forState:UIControlStateSelected | UIControlStateDisabled];
    
    [button setTitleEdgeInsets:UIEdgeInsetsFromString([QwayUtils getDictEntry:attributes key:@"title-edge"])];
    [button setContentEdgeInsets:UIEdgeInsetsFromString([QwayUtils getDictEntry:attributes key:@"content-edge"])];
    [button setImageEdgeInsets:UIEdgeInsetsFromString([QwayUtils getDictEntry:attributes key:@"image-edge"])];
    
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-normal"] forState:UIControlStateNormal];
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-highlighted"]
            forState:UIControlStateHighlighted];
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-disabled"] forState:UIControlStateDisabled];
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-selected"] forState:UIControlStateSelected];
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-disabled-highlighted"]
            forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-selected-highlighted"]
            forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setImage:[QwayUtils getDictEntry:attributes key:@"image-selected-disabled"]
            forState:UIControlStateSelected | UIControlStateDisabled];
    
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-normal"]
                      forState:UIControlStateNormal];
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-highlighted"]
                      forState:UIControlStateHighlighted];
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-disabled"]
                      forState:UIControlStateDisabled];
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-selected"]
                      forState:UIControlStateSelected];
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-disabled-highlighted"]
                      forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-selected-highlighted"]
                      forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setBackgroundImage:[QwayUtils getDictEntry:attributes key:@"background-selected-disabled"]
                      forState:UIControlStateSelected | UIControlStateDisabled];
}

+ (void)addDictEntry:(NSMutableDictionary *)dict item:(id)item key:(id)key {
    if (item != nil && key != nil) {
        [dict setObject:item forKey:key];
    }
}

+ (id)getDictEntry:(NSDictionary *)dict key:(id)key {
    if (key != nil) {
        return [dict objectForKey:key];
    }
    return nil;
}

+ (NSString *)deviceModelIdentifier {
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([machine isEqual:@"iPad1,1"])
        return @"iPad";
    else if ([machine isEqual:@"iPad2,1"])
        return @"iPad 2";
    else if ([machine isEqual:@"iPad2,2"])
        return @"iPad 2";
    else if ([machine isEqual:@"iPad2,3"])
        return @"iPad 2";
    else if ([machine isEqual:@"iPad2,4"])
        return @"iPad 2";
    else if ([machine isEqual:@"iPad3,1"])
        return @"iPad 3";
    else if ([machine isEqual:@"iPad3,2"])
        return @"iPad 3";
    else if ([machine isEqual:@"iPad3,3"])
        return @"iPad 3";
    else if ([machine isEqual:@"iPad3,4"])
        return @"iPad 4";
    else if ([machine isEqual:@"iPad3,5"])
        return @"iPad 4";
    else if ([machine isEqual:@"iPad3,6"])
        return @"iPad 4";
    else if ([machine isEqual:@"iPad4,1"])
        return @"iPad Air";
    else if ([machine isEqual:@"iPad4,2"])
        return @"iPad Air";
    else if ([machine isEqual:@"iPad4,3"])
        return @"iPad Air";
    else if ([machine isEqual:@"iPad5,3"])
        return @"iPad Air 2";
    else if ([machine isEqual:@"iPad5,4"])
        return @"iPad Air 2";
    else if ([machine isEqual:@"iPad6,7"])
        return @"iPad Pro 12.9";
    else if ([machine isEqual:@"iPad6,8"])
        return @"iPad Pro 12.9";
    else if ([machine isEqual:@"iPad6,3"])
        return @"iPad Pro 9.7";
    else if ([machine isEqual:@"iPad6,4"])
        return @"iPad Pro 9.7";
    else if ([machine isEqual:@"iPad2,5"])
        return @"iPad mini";
    else if ([machine isEqual:@"iPad2,6"])
        return @"iPad mini";
    else if ([machine isEqual:@"iPad2,7"])
        return @"iPad mini";
    else if ([machine isEqual:@"iPad4,4"])
        return @"iPad mini 2";
    else if ([machine isEqual:@"iPad4,5"])
        return @"iPad mini 2";
    else if ([machine isEqual:@"iPad4,6"])
        return @"iPad mini 2";
    else if ([machine isEqual:@"iPad4,7"])
        return @"iPad mini 3";
    else if ([machine isEqual:@"iPad4,8"])
        return @"iPad mini 3";
    else if ([machine isEqual:@"iPad4,9"])
        return @"iPad mini 3";
    else if ([machine isEqual:@"iPad5,1"])
        return @"iPad mini 4";
    else if ([machine isEqual:@"iPad5,2"])
        return @"iPad mini 4";
    
    else if ([machine isEqual:@"iPhone1,1"])
        return @"iPhone";
    else if ([machine isEqual:@"iPhone1,2"])
        return @"iPhone 3G";
    else if ([machine isEqual:@"iPhone2,1"])
        return @"iPhone 3GS";
    else if ([machine isEqual:@"iPhone3,1"])
        return @"iPhone3,2 iPhone3,3	iPhone 4";
    else if ([machine isEqual:@"iPhone4,1"])
        return @"iPhone 4S";
    else if ([machine isEqual:@"iPhone5,1"])
        return @"iPhone5,2	iPhone 5";
    else if ([machine isEqual:@"iPhone5,3"])
        return @"iPhone5,4	iPhone 5c";
    else if ([machine isEqual:@"iPhone6,1"])
        return @"iPhone6,2	iPhone 5s";
    else if ([machine isEqual:@"iPhone7,2"])
        return @"iPhone 6";
    else if ([machine isEqual:@"iPhone7,1"])
        return @"iPhone 6 Plus";
    else if ([machine isEqual:@"iPhone8,1"])
        return @"iPhone 6s";
    else if ([machine isEqual:@"iPhone8,2"])
        return @"iPhone 6s Plus";
    else if ([machine isEqual:@"iPhone8,4"])
        return @"iPhone SE";
    
    else if ([machine isEqual:@"iPod1,1"])
        return @"iPod touch";
    else if ([machine isEqual:@"iPod2,1"])
        return @"iPod touch 2G";
    else if ([machine isEqual:@"iPod3,1"])
        return @"iPod touch 3G";
    else if ([machine isEqual:@"iPod4,1"])
        return @"iPod touch 4G";
    else if ([machine isEqual:@"iPod5,1"])
        return @"iPod touch 5G";
    else if ([machine isEqual:@"iPod7,1"])
        return @"iPod touch 6G";
    
    // none matched: cf https://www.theiphonewiki.com/wiki/Models for the whole list
    LOGW(@"%s: Oops, unknown machine %@... consider completing me!", __FUNCTION__, machine);
    return machine;
}

+ (LinphoneAddress *)normalizeSipOrPhoneAddress:(NSString *)value {
    if (!value) {
        return NULL;
    }
    
    LinphoneProxyConfig *cfg = linphone_core_get_default_proxy_config(LC);
    LinphoneAddress *addr = linphone_proxy_config_normalize_sip_uri(cfg, value.UTF8String);
    
    // since user wants to escape plus, we assume it expects to have phone numbers by default
    if (addr && cfg && linphone_proxy_config_get_dial_escape_plus(cfg)) {
        char *phone = linphone_proxy_config_normalize_phone_number(cfg, value.UTF8String);
        if (phone) {
            linphone_address_set_username(addr, phone);
            ms_free(phone);
        }
    }
    
    return addr;
}

@end

@implementation NSNumber (HumanReadableSize)

- (NSString *)toHumanReadableSize {
    float floatSize = [self floatValue];
    if (floatSize < 1023)
        return ([NSString stringWithFormat:@"%1.0f bytes", floatSize]);
    floatSize = floatSize / 1024;
    if (floatSize < 1023)
        return ([NSString stringWithFormat:@"%1.1f KB", floatSize]);
    floatSize = floatSize / 1024;
    if (floatSize < 1023)
        return ([NSString stringWithFormat:@"%1.1f MB", floatSize]);
    floatSize = floatSize / 1024;
    
    return ([NSString stringWithFormat:@"%1.1f GB", floatSize]);
}

@end

@implementation NSString (md5)

- (NSString *)md5 {
    const char *ptr = [self UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(ptr, (unsigned int)strlen(ptr), md5Buffer);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", md5Buffer[i]];
    }
    
    return output;
}

- (BOOL)containsSubstring:(NSString *)str {
    if (UIDevice.currentDevice.systemVersion.doubleValue >= 8.0) {
#pragma deploymate push "ignored-api-availability"
        return [self containsString:str];
#pragma deploymate pop
    }
    return ([self rangeOfString:str].location != NSNotFound);
}

@end
