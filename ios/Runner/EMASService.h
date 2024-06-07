//
//  EMASService.h
//  EMASDemo
//
//  Created by EMAS on 2018/1/15.
//  Copyright © 2018年 EMAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EMASService : NSObject

+ (EMASService *)shareInstance;

- (NSString *)appkey;
- (NSString *)appSecret;
- (NSString *)getAppVersion;
- (NSString *)ACCSDomain;
- (NSDictionary *)IPStrategy;
- (NSString *)HAServiceID;
- (NSString *)MTOPDomain;
- (NSString *)ChannelID;
- (NSString *)ZCacheURL;
- (NSString *)APIDomain;
- (NSString *)HAOSSBucketName;
- (NSString *)HAUploadType;
- (NSString *)HAUniversalHost;
- (NSString *)HATimestampHost;
- (NSString *)HARSAPublicKey;
- (NSString *)HotfixServerURL;
- (NSString *)RemoteConfigHost;
- (BOOL)useHTTP;

@end
