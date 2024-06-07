//
//  EMASMainViewController.m
//  Runner
//
//  Created by sky on 2022/12/2.
//

#import "EMASMainViewController.h"
#import "GeneratedPluginRegistrant.h"
#import "EMASMainViewController.h"

#import <AliEMASConfigure/AliEMASConfigure.h>

#import <WindVane/WindVane.h>
#import <EMASMiniAppContainer/EMASWindVaneConfig.h>
#import <EMASServiceManager/EMASServiceManager.h>
#import <EMASMiniAppContainer/EMASMiniAppServiceImpl.h>
#import <ZCache/ZCache.h>
#import "EMASService.h"

#import <DynamicConfigurationAdaptor/DynamicConfigurationAdaptorManager.h>

#import <MtopSDK/MtopSDK.h>
#import <MtopCore/MtopService.h>
#import <MtopCore/TBSDKConfiguration.h>

@interface EMASMainViewController ()
@property (nonatomic, strong) FlutterMethodChannel* messageChannel;
@end

@implementation EMASMainViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configMessageChannel];

}


-(void) configMessageChannel{
    //获取当前的 controller
//    FlutterViewController* controller = (FlutterViewController*)[UIApplication sharedApplication].delegate.window.rootViewController;

    
    self.messageChannel = [FlutterMethodChannel methodChannelWithName:@"windvane_miniapp" binaryMessenger:self.binaryMessenger];
    
    __weak __typeof__(self) weakSelf = self;
    [self.messageChannel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        NSLog(@"call method is %@",call.method);
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString *method = call.method;
        
        if ([method isEqualToString:@"initWindVaneMiniApp"]) {
            [strongSelf initWindVaneMiniApp:call result:result];
        } else if ([method isEqualToString:@"loadMiniApp"]) {
            [strongSelf loadMiniApp:call result:result];
        } else if ([method isEqualToString:@"getMiniApps"]) {
            [strongSelf getMiniApps:call result:result];
        }
        
    }];
    
}

- (void)initWindVaneMiniApp:(FlutterMethodCall *)call result:(FlutterResult)result {
    [AliEMASConfigure configure];

    [self initMtopConfig];

    [self initZCacheConfig];
    
    [EMASWindVaneConfig setUpWindVanePlugin];
    
    [[EMASServiceManager sharedInstance] registerServiceProtocol:@"EMASMiniAppService" IMPClass:@"EMASMiniAppServiceImpl" target:[EMASMiniAppServiceImpl new]];
    
    result(nil);
}


- (void)loadMiniApp:(FlutterMethodCall *)call result:(FlutterResult)result {
    
    NSString *appId = call.arguments[@"appId"];
    
    if (appId) {
        id<EMASMiniAppService> miniAppService = [[EMASServiceManager sharedInstance] serviceForProtocol:@"EMASMiniAppService"];
        if (miniAppService) {
            [miniAppService loadMiniAppWithAppId:appId];
            result(nil);
            
        }
    } else {
        result(nil);
    }

}

- (void)getMiniApps:(FlutterMethodCall *)call result:(FlutterResult)result {
    id<EMASMiniAppService> miniAppService = [[EMASServiceManager sharedInstance] serviceForProtocol:@"EMASMiniAppService"];
    if (miniAppService) {
        
        
        [miniAppService getMiniAppListWithCompletionBlock:^(NSArray * _Nonnull miniApps) {
            
            NSMutableArray *windvaneMiniApps = [NSMutableArray array];
            
            for (NSDictionary *item in miniApps) {
                NSString *appType = item[@"appType"];
                if ([appType isEqualToString:@"WindVane"]) {
                    
                    NSMutableDictionary *miniApp = [NSMutableDictionary dictionary];
                    [miniApp setValue:[item valueForKey:@"name"] forKey:@"appName"];
                    [miniApp setValue:[item valueForKey:@"appId"] forKey:@"appId"];
                    [miniApp setValue:[item valueForKey:@"icon"] forKey:@"appIcon"];

                    [windvaneMiniApps addObject:miniApp];
                }
            }
            
            // use mini apps
            
            NSDictionary *resultDict = @{
                @"miniApps": windvaneMiniApps,
                @"success": @YES
            };
            
            NSString *resultString = resultDict.wvJSONString;
            
            NSLog(@"getMiniApps = %@", resultString);
            
            result(resultString);
            
        }];
        
        
    } else {
        result(nil);
    }
}

- (void)initMtopConfig
{
    TBSDKConfiguration *config = [TBSDKConfiguration shareInstanceDisableDeviceID:YES andSwitchOffServerTime:YES];
    config.environment = TBSDKEnvironmentRelease;
    if ([[EMASService shareInstance] useHTTP])
    {
        config.enableHttps = NO;
    }
    config.safeSecret = NO;
    config.appKey = [[EMASService shareInstance] appkey];
    config.appSecret = [[EMASService shareInstance] appSecret];
    config.wapAPIURL = [[EMASService shareInstance] MTOPDomain];
    config.wapTTID = [[EMASService shareInstance] ChannelID];
    openSDKSwitchLog(YES);
}

- (void)initZCacheConfig
{
#ifdef DEBUG
    [ZCache setDebugMode:YES];
#endif
    [ZCache setupWithMtop];
    [ZCache defaultCommonConfig].packageZipPrefix = [[EMASService shareInstance] ZCacheURL];
}


@end
