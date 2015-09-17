/*
 * Copyright (c) Microsoft Corporation.  All rights reserved.
 * Licensed under the MIT license. See License.txt in the project root for license information.
 */

#include <sys/types.h>
#include <sys/sysctl.h>
#include "AZME.h"
#import <Cordova/CDV.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define AZME_PLUGIN_VERSION @"2.0.1"
#define NATIVE_PLUGIN_VERSION @"3.1.0"
#define CDVAZME_TAG @"[cdvazme-test] "
#define CDVAZME_ERROR @"[cdvazme-test] ERROR: "

static bool enableLog = false;

@implementation AppDelegate(AZME)

// Use swizzling
// http://stackoverflow.com/questions/1085479/override-a-method-via-objc-category-and-call-the-default-implementation

- (void)application:(UIApplication *)application  azmeDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    if (enableLog)
        NSLog(CDVAZME_TAG @"azmeDidFailToRegisterForRemoteNotificationsWithError %@", error);
    
    // call the previous implementation (and not itself!)
    [self application:application azmeDidFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application  azmeDidReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler
{
    if (enableLog)
        NSLog(CDVAZME_TAG @"azmedidReceiveRemoteNotificationfetchCompletionHandler");
    
    [[EngagementAgent shared] applicationDidReceiveRemoteNotification:userInfo fetchCompletionHandler:handler];
    
    // call the previous implementation (and not itself!)
    [self application:application azmeDidReceiveRemoteNotification:userInfo fetchCompletionHandler:handler];
}

// IOS6 Support
- (void)application:(UIApplication*)application azmeDidReceiveRemoteNotification:(NSDictionary*)userInfo
{
    if (enableLog)
        NSLog(CDVAZME_TAG @"azmeDidReceiveRemoteNotification");
    
    [[EngagementAgent shared] applicationDidReceiveRemoteNotification:userInfo fetchCompletionHandler:nil];
    
    // call the previous implementation (and not itself!)
    [self application:application azmeDidReceiveRemoteNotification:userInfo];
}

- (void)application:(UIApplication *)application azmeDidRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    if (enableLog)
        NSLog(CDVAZME_TAG @"azmeDidRegisterForRemoteNotificationsWithDeviceToken");
    
    [[EngagementAgent shared] registerDeviceToken:deviceToken];
    
    // call the previous implementation (and not itself!)
    [self application:application azmeDidRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

//  used in case the "parent" delegate was not implemented
- (void)application:(UIApplication *)application azmeEmpty:(id)_fake
{
    
}

+ (void)swizzleInstanceSelector:(SEL)originalSelector withNewSelector:(SEL)newSelector
{
    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    Method newMethod = class_getInstanceMethod(self, newSelector);
    
    // if the original Method does not exist, replace it with an empty implementation
    if (originalMethod==nil)
    {
        Method emptyMethod = class_getInstanceMethod(self, @selector(application:azmeEmpty:));
        BOOL methodAdded = class_addMethod([self class],
                                           originalSelector,
                                           method_getImplementation(emptyMethod), // empty code
                                           method_getTypeEncoding(newMethod)); // but keep signature
        
        if (methodAdded==false)
            NSLog(CDVAZME_TAG @"Failed to add method %@",NSStringFromSelector(originalSelector));
        
        originalMethod = class_getInstanceMethod(self, originalSelector);
    }
    
    method_exchangeImplementations(originalMethod, newMethod);
}

+ (void)load
{
    
    NSString* str = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AZME_ENABLE_LOG"];
    enableLog = ([str compare:@"1"] == NSOrderedSame || [str caseInsensitiveCompare:@"true"] == NSOrderedSame );
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"Plugin cordova-plugin-ms-azure-mobile-engagement v" AZME_PLUGIN_VERSION " (SDK Version "NATIVE_PLUGIN_VERSION")");
    
    [self swizzleInstanceSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                  withNewSelector:@selector(application:azmeDidFailToRegisterForRemoteNotificationsWithError:)];
    
    [self swizzleInstanceSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                  withNewSelector:@selector(application:azmeDidReceiveRemoteNotification:fetchCompletionHandler:)];
    
    [self swizzleInstanceSelector:@selector(application:didReceiveRemoteNotification:)
                  withNewSelector:@selector(application:azmeDidReceiveRemoteNotification:)];
    
    [self swizzleInstanceSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                  withNewSelector:@selector(application:azmeDidRegisterForRemoteNotificationsWithDeviceToken:)];
}

@end

@implementation AZME

- (void)pluginInitialize
{
    
    NSString* AZME_IOS_CONNECTION_STRING = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AZME_IOS_CONNECTION_STRING"];
    NSString* AZME_IOS_REACH_ICON = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AZME_IOS_REACH_ICON"];
    
    if (AZME_IOS_CONNECTION_STRING.length != 0)
    {
        
        if (enableLog)
        {
            NSLog(CDVAZME_TAG @"Initializing AZME with ConnectionString:%@", AZME_IOS_CONNECTION_STRING);
            [EngagementAgent setTestLogEnabled:YES];
        }
        
        @try {
            
            AEReachModule* reach = nil;
            if (AZME_IOS_REACH_ICON.length > 0)
            {
                if (enableLog)
                    NSLog(CDVAZME_TAG @"Preparing Reach Module with Icon :%@", AZME_IOS_REACH_ICON);
                
                UIImage* icon = [UIImage imageNamed:AZME_IOS_REACH_ICON];
                if (icon == nil)
                    NSLog(CDVAZME_ERROR @"Icon '%@' missing", AZME_IOS_REACH_ICON);
                
                reach = [AEReachModule moduleWithNotificationIcon:icon];
                if (reach == nil)
                    NSLog(CDVAZME_ERROR @"Failed to initialize reach");
                else
                {
                    [reach setAutoBadgeEnabled:YES];
                    [reach setDataPushDelegate:self];
                }
            }
            
            [EngagementAgent init:AZME_IOS_CONNECTION_STRING modules:reach, nil];
          
        
            
            NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  AZME_PLUGIN_VERSION, @"CDVAZMEVersion",  nil];
            
            [[EngagementAgent shared] sendAppInfo:dict];
            
        }
        @catch (NSException * e) {
            NSLog(CDVAZME_ERROR @"Failed to initialize AZME, Exception: %@", e);
        }
    }
    else
        NSLog( CDVAZME_ERROR @"AZME_IOS_CONNECTION_STRING not set");
}

-(BOOL)didReceiveStringDataPushWithCategory:(NSString*)category body:(NSString*)body
{
    if (enableLog)
        NSLog(CDVAZME_TAG @"String data push message with category <%@> received: %@", category, body);

    NSString* jsString = [NSString stringWithFormat:@"AzureEngagement.handleDataPush(\"%@\",\"%@\");", category,body];
    [self.commandDelegate evalJs:jsString];

   return YES;
}

-(BOOL)didReceiveBase64DataPushWithCategory:(NSString*)category decodedBody:(NSData *)decodedBody encodedBody:(NSString *)encodedBody
{
    if (enableLog)
        NSLog(@"Base64 data push message with category <%@> received: %@", category, encodedBody);

    NSString* jsString = [NSString stringWithFormat:@"AzureEngagement.handleDataPush(\"%@\",\"%@\");", category,encodedBody];
    [self.commandDelegate evalJs:jsString];

   return YES;
}

- (void)startActivity:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    NSString *name = [command.arguments objectAtIndex:0];
    NSString *param = [command.arguments objectAtIndex:1];
    NSDictionary *JSON ;
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"startActivity:%@",name);
    
    JSON = [NSJSONSerialization     JSONObjectWithData: [param dataUsingEncoding:NSUTF8StringEncoding]
                                               options: NSJSONReadingMutableContainers
                                                 error: nil];
    [[EngagementAgent shared] startActivity:name extras:JSON];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)endActivity:(CDVInvokedUrlCommand*)command
{
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"endActivity");
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    
    [[EngagementAgent shared] endActivity];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)sendEvent:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    NSString *name = [command.arguments objectAtIndex:0];
    NSString *param = [command.arguments objectAtIndex:1];
    NSDictionary *JSON ;
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"sendEvent:%@",name);
    
    JSON = [NSJSONSerialization     JSONObjectWithData: [param dataUsingEncoding:NSUTF8StringEncoding]
                                               options: NSJSONReadingMutableContainers
                                                 error: nil];
    [[EngagementAgent shared] sendEvent:name extras:JSON];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startJob:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    NSString *name = [command.arguments objectAtIndex:0];
    NSString *param = [command.arguments objectAtIndex:1];
    NSDictionary *JSON ;
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"startJob:%@",name);
    
    JSON = [NSJSONSerialization     JSONObjectWithData: [param dataUsingEncoding:NSUTF8StringEncoding]
                                               options: NSJSONReadingMutableContainers
                                                 error: nil];
    [[EngagementAgent shared] startJob:name extras:JSON];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)endJob:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    NSString *name = [command.arguments objectAtIndex:0];
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"endJob:%@",name);
    
    [[EngagementAgent shared] endJob:name];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)sendAppInfo:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    NSString *param = [command.arguments objectAtIndex:0];
    NSDictionary *JSON ;
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"sendAppInfo:%@",param);
    
    JSON = [NSJSONSerialization JSONObjectWithData: [param dataUsingEncoding:NSUTF8StringEncoding]
                                           options: NSJSONReadingMutableContainers
                                             error: nil];
    [[EngagementAgent shared] sendAppInfo:JSON];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getStatus:(CDVInvokedUrlCommand*)command
{
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          AZME_PLUGIN_VERSION, @"pluginVersion",
                          NATIVE_PLUGIN_VERSION, @"AZMEVersion",
                          [[EngagementAgent shared] deviceId], @"deviceId",
                          nil];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsDictionary:dict];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// CheckRedirect does nothing on iOS
- (void)checkRedirect:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsString:nil ];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)handleOpenURL:(NSNotification*)notification
{
    NSString* url = [notification object];
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"handleOpenURL with :%@",url);
    
    NSString* jsString = [NSString stringWithFormat:@"AzureEngagement.handleOpenURL(\"%@\");", url];
    [self.commandDelegate evalJs:jsString];
}

- (void)registerForPushNotification:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK ];
    
    if (enableLog)
        NSLog(CDVAZME_TAG @"register the application for Push notifications");
    
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
