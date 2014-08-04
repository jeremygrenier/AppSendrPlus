//
//  App.h
//  AppSendr
//
//  Created by Nolan Brown on 5/6/11.
//  Copyright 2013 AppSendr. See LICENSE.txt for Licensing Infomation
//

#import <Foundation/Foundation.h>
#import "ASApp.h"

@class ASIcon;

@interface iOSApp : ASApp <NSCoding>
{
    NSDictionary *_dataProfile;

    NSString *_originalPath;
    NSString *_workingPath;
    NSString *_name;
    
@private
    NSArray *_files;
	NSFileHandle *_fileHandle;
    NSTask *_task;
}

@property (nonatomic, copy) NSString *ipaPath;
@property (nonatomic, copy) NSString *appPath;
@property (nonatomic, strong) NSDictionary *bundleInfo;

@property (nonatomic, strong) NSDictionary *provisioningProfile;
@property (nonatomic, strong) NSArray *provisionedDevices;

@property (nonatomic, strong) NSArray *assets;

- (id)initWithSourcePath:(NSString *)sourcePath proccessingFinished:(void (^)(ASApp *app, BOOL success))callback;

@end
