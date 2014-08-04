//
//  ASSettingsWindow.h
//  AppSendr+
//
//  Created by Jeremy GRENIER on 30/06/2014.
//  Copyright (c) 2014 AppSendr. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ASSettingsWindow : NSWindow <NSWindowDelegate>

@property (weak) IBOutlet NSTextField *numDropsTextField;
@property (weak) IBOutlet NSSlider *numDropsSlider;

@end
