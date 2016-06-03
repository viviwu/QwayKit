//
//  QwayManager.h
//  QwayKit
//
//  Created by qway on 16/6/3.
//  Copyright © 2016年 qway. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <AVFoundation/AVAudioSession.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <CoreTelephony/CTCallCenter.h>

#import <sqlite3.h>
#include "linphone/linphonecore.h"


extern NSString *const LINPHONERC_APPLICATION_KEY;

extern NSString *const kQwayCoreUpdate;
extern NSString *const kQwayDisplayStatusUpdate;
extern NSString *const kQwayMessageReceived;
extern NSString *const kQwayTextComposeEvent;
extern NSString *const kQwayCallUpdate;
extern NSString *const kQwayRegistrationUpdate;
extern NSString *const kQwayMainViewChange;
extern NSString *const kQwayAddressBookUpdate;
extern NSString *const kQwayLogsUpdate;
extern NSString *const kQwaySettingsUpdate;
extern NSString *const kQwayBluetoothAvailabilityUpdate;
extern NSString *const kQwayConfiguringStateUpdate;
extern NSString *const kQwayGlobalStateUpdate;
extern NSString *const kQwayNotifyReceived;
extern NSString *const kQwayCallEncryptionChanged;
extern NSString *const kQwayFileTransferSendUpdate;
extern NSString *const kQwayFileTransferRecvUpdate;

typedef enum _NetworkType {
    network_none = 0,
    network_2g,
    network_3g,
    network_4g,
    network_lte,
    network_wifi
} NetworkType;

typedef enum _Connectivity {
    wifi,
    wwan,
    none
} Connectivity;

extern const int kQwayAudioVbrCodecDefaultBitrate;

/* Application specific call context */
typedef struct _CallContext {
    LinphoneCall* call;
    bool_t cameraIsEnabled;
} CallContext;

struct NetworkReachabilityContext {
    bool_t testWifi, testWWan;
    void (*networkStateChanged) (Connectivity newConnectivity);
};

@interface LinphoneCallAppData :NSObject {
@public
    bool_t batteryWarningShown;
    UILocalNotification *notification;
    NSMutableDictionary *userInfos;
    bool_t videoRequested; /*set when user has requested for video*/
    NSTimer* timer;
};
@end

typedef struct _QwayManagerSounds {
    SystemSoundID vibrate;
} QwayManagerSounds;

@interface QwayManager : NSObject {
@protected
    SCNetworkReachabilityRef proxyReachability;
    
@private
    NSTimer* mIterateTimer;
    NSMutableArray*  pushCallIDs;
    Connectivity connectivity;
    UIBackgroundTaskIdentifier pausedCallBgTask;
    UIBackgroundTaskIdentifier incallBgTask;
    CTCallCenter* mCallCenter;
    NSDate *mLastKeepAliveDate;
@public
    CallContext currentCallContextBeforeGoingBackground;
}
+ (QwayManager*)instance;
#ifdef DEBUG
+ (void)instanceRelease;
#endif
+ (LinphoneCore*) getLc;
+ (BOOL)runningOnIpad;
+ (BOOL)isNotIphone3G;
+ (NSString *)getPreferenceForCodec: (const char*) name withRate: (int) rate;
+ (BOOL)isCodecSupported: (const char*)codecName;
+ (NSSet *)unsupportedCodecs;
+ (NSString *)getUserAgent;
+ (int)unreadMessageCount;

- (void)playMessageSound;
- (void)resetLinphoneCore;
- (void)startLinphoneCore;
- (void)destroyLinphoneCore;
- (BOOL)resignActive;
- (void)becomeActive;
- (BOOL)enterBackgroundMode;
- (void)addPushCallId:(NSString*) callid;
- (void)configurePushTokenForProxyConfig: (LinphoneProxyConfig*)cfg;
- (BOOL)popPushCallID:(NSString*) callId;
- (void)acceptCallForCallId:(NSString*)callid;
- (void)cancelLocalNotifTimerForCallId:(NSString*)callid;

+ (BOOL)langageDirectionIsRTL;
+ (void)kickOffNetworkConnection;
- (void)setupNetworkReachabilityCallback;

- (void)refreshRegisters;

- (bool)allowSpeaker;

- (void)configureVbrCodecs;

+ (BOOL)copyFile:(NSString*)src destination:(NSString*)dst override:(BOOL)override;
+ (NSString*)bundleFile:(NSString*)file;
+ (NSString*)documentFile:(NSString*)file;
+ (NSString*)cacheDirectory;

- (void)acceptCall:(LinphoneCall *)call evenWithVideo:(BOOL)video;
- (BOOL)call:(const LinphoneAddress *)address;

+(id)getMessageAppDataForKey:(NSString*)key inMessage:(LinphoneChatMessage*)msg;
+(void)setValueInMessageAppData:(id)value forKey:(NSString*)key inMessage:(LinphoneChatMessage*)msg;

- (void)lpConfigSetString:(NSString*)value forKey:(NSString*)key;
- (void)lpConfigSetString:(NSString *)value forKey:(NSString *)key inSection:(NSString *)section;
- (NSString *)lpConfigStringForKey:(NSString *)key;
- (NSString *)lpConfigStringForKey:(NSString *)key inSection:(NSString *)section;
- (NSString *)lpConfigStringForKey:(NSString *)key withDefault:(NSString *)value;
- (NSString *)lpConfigStringForKey:(NSString *)key inSection:(NSString *)section withDefault:(NSString *)value;

- (void)lpConfigSetInt:(int)value forKey:(NSString *)key;
- (void)lpConfigSetInt:(int)value forKey:(NSString *)key inSection:(NSString *)section;
- (int)lpConfigIntForKey:(NSString *)key;
- (int)lpConfigIntForKey:(NSString *)key inSection:(NSString *)section;
- (int)lpConfigIntForKey:(NSString *)key withDefault:(int)value;
- (int)lpConfigIntForKey:(NSString *)key inSection:(NSString *)section withDefault:(int)value;

- (void)lpConfigSetBool:(BOOL)value forKey:(NSString*)key;
- (void)lpConfigSetBool:(BOOL)value forKey:(NSString *)key inSection:(NSString *)section;
- (BOOL)lpConfigBoolForKey:(NSString *)key;
- (BOOL)lpConfigBoolForKey:(NSString *)key inSection:(NSString *)section;
- (BOOL)lpConfigBoolForKey:(NSString *)key withDefault:(BOOL)value;
- (BOOL)lpConfigBoolForKey:(NSString *)key inSection:(NSString *)section withDefault:(BOOL)value;

- (void)silentPushFailed:(NSTimer*)timer;

- (void)removeAllAccounts;

+ (BOOL)isMyself:(const LinphoneAddress *)addr;

@property (readonly) BOOL isTesting;
//@property(readonly, strong) FastAddressBook *fastAddressBook;
@property Connectivity connectivity;
@property (readonly) NetworkType network;
@property (readonly) const char*  frontCamId;
@property (readonly) const char*  backCamId;
@property(strong, nonatomic) NSString *SSID;
@property (readonly) sqlite3* database;
@property(nonatomic, strong) NSData *pushNotificationToken;
@property (readonly) QwayManagerSounds sounds;
@property (readonly) NSMutableArray *logs;
@property (nonatomic, assign) BOOL speakerEnabled;
@property (nonatomic, assign) BOOL bluetoothAvailable;
@property (nonatomic, assign) BOOL bluetoothEnabled;
@property (readonly) ALAssetsLibrary *photoLibrary;
@property (readonly) NSString* contactSipField;
@property (readonly,copy) NSString* contactFilter;
@property (copy) void (^silentPushCompletion)(UIBackgroundFetchResult);
@property (readonly) BOOL wasRemoteProvisioned;
@property (readonly) LpConfig *configDb;
//@property(readonly) InAppProductsManager *iapManager;
@property(strong, nonatomic) NSMutableArray *fileTransferDelegates;
@property BOOL nextCallIsTransfer;

@end
