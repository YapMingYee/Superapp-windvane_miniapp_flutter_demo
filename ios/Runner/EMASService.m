//
//  EMASService.m
//  EMASDemo
//
//  Created by EMAS on 2018/1/15.
//  Copyright © 2018年 EMAS. All rights reserved.
//

#import "EMASService.h"

@implementation EMASService
{
    NSDictionary *services;
}

+ (EMASService *)shareInstance {
    static EMASService *g_instance = nil;
    static  dispatch_once_t pred = 0;
    dispatch_once(&pred, ^{
        g_instance = [[EMASService alloc] init];
    });
    return g_instance;
}

- (id)init
{
    if (self = [super init])
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"AliyunEmasServices-Info" ofType:@"plist"];
        NSDictionary *root = [NSDictionary dictionaryWithContentsOfFile:path];
        services = [root objectForKey:@"private_cloud_config"];
    }
    return self;
}

- (NSString *)appkey
{
    return [services objectForKey:@"AppKey"];
}

- (NSString *)appSecret
{
    return [services objectForKey:@"AppSecret"];
}

- (NSString *)getAppVersion
{
    NSDictionary *appinfo = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [appinfo objectForKey:@"CFBundleShortVersionString"];
    if (!version) {
        version = @"10.0.0";
    }
    return version;
}

- (NSString *)ACCSDomain
{
    NSDictionary *dict = [services objectForKey:@"ACCS"];
    return [dict objectForKey:@"Host"];
}

- (NSDictionary *)IPStrategy
{
    NSDictionary *dict = [services objectForKey:@"Network"];
    return [dict objectForKey:@"IPStrategy"];
}

- (NSString *)HAServiceID
{
    return [services objectForKey:@"HAServiceID"];
}

- (NSString *)APIDomain {
    NSDictionary *dict = [services objectForKey:@"MTOP"];
    return [dict objectForKey:@"APIDomain"];
}

- (NSString *)MTOPDomain
{
    NSDictionary *dict = [services objectForKey:@"MTOP"];
    return [dict objectForKey:@"Domain"];
}

- (NSString *)ChannelID
{
    return [services objectForKey:@"ChannelID"];
}

- (NSString *)ZCacheURL
{
    NSDictionary *dict = [services objectForKey:@"ZCache"];
    NSString *url = [dict objectForKey:@"URL"];
    
    NSUInteger length = url.length;
    if (length >= 1) {
        NSString *lastWord = [url substringFromIndex:length - 1];
        if (![lastWord isEqualToString:@"/"]) {
            url = [url stringByAppendingString:@"/"];
        }
    }
    
    return url;
}

- (NSString *)HAOSSBucketName
{
    NSDictionary *dict = [services objectForKey:@"HA"];
    return [dict objectForKey:@"OSSBucketName"];
}

- (NSString *)HAUploadType
{
    NSDictionary *dict = [services objectForKey:@"HA"];
    return [dict objectForKey:@"UploadType"];
}

- (NSString *)HAUniversalHost
{
    NSDictionary *dict = [services objectForKey:@"HA"];
    return [dict objectForKey:@"UniversalHost"];
}

- (NSString *)HATimestampHost
{
    NSDictionary *dict = [services objectForKey:@"HA"];
    return [dict objectForKey:@"TimestampHost"];
}

- (NSString *)HARSAPublicKey
{
    NSDictionary *dict = [services objectForKey:@"HA"];
    return [dict objectForKey:@"RSAPublicKey"];
}

- (NSString *)HotfixServerURL
{
    NSDictionary *dict = [services objectForKey:@"Hotfix"];
    NSString *domain = [dict objectForKey:@"URL"];
    
    if ([domain hasPrefix:@"https"] ||
        [domain hasPrefix:@"http"]) {
        return domain;
    }
    
    NSString *scheme = @"https";
    if ([self useHTTP]) {
        scheme = @"http";
    }
    
    return [NSString stringWithFormat:@"%@://%@", scheme, domain];
}

- (BOOL)useHTTP
{
    return [[services objectForKey:@"UseHTTP"] boolValue];
}

- (NSString *)RemoteConfigHost
{
    NSDictionary *dict = [services objectForKey:@"RemoteConfig"];
    return [dict objectForKey:@"Domain"];
}

@end
