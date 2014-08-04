//
//  ASAPIClient.h
//  AppSendr
//
//  Created by Nolan Brown on 1/31/12.
//  Modifed by Jeremy Grenier on 6/29/14.
//  Copyright (c) 2012AppSendr. See LICENSE.txt for Licensing Infomation
//

#import <AFNetworking/AFHTTPClient.h>
#import "Constants.h"

@class ASApp, AppSendr;

@interface ASAPIClient : AFHTTPClient

+ (ASAPIClient *)sharedClient;

- (void)uploadApp:(ASApp *)app withProgressCallback:(void (^)(CGFloat progess))progress finished:(void (^)(BOOL successful, id response))finished;

- (void)destroyApp:(ASApp*)app finished:(void (^)(BOOL successful))finished;

@end
