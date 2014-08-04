//
//  ASAppDelegate.h
//  AppSendr
//
//  Created by Nolan Brown on 4/10/12.
//  Modifed by Jeremy Grenier on 6/29/14.
//  Copyright (c) 2013 AppSendr. See LICENSE.txt for Licensing Infomation
//

#import <Cocoa/Cocoa.h>
#import "ASIPADropView.h"
#import "MAAttachedWindow.h"

extern NSString * const ASResetMenuNotification;

@interface ASAppDelegate : NSObject <NSApplicationDelegate, ASIPADropViewDelegate, NSMenuDelegate, NSWindowDelegate>
{
    @private
    NSUserDefaults *_defaults;
	NSStatusItem *_statusItem;
    ASIPADropView *_dropView;
    MAAttachedWindow *_urlCopiedWindow;
    NSMutableArray *_menuItems;
    
    NSArray *_orderedApps;
    BOOL _reloadOpenApps;
    
}

@property (assign) BOOL checkForUpdates;

@property IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *statusItemMenu;
@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet NSView *generalSettingsView;
@property (weak) IBOutlet NSView *advancedSettingsView;

@property (weak) IBOutlet NSView *copiedURLView;
@property (weak) IBOutlet NSTextField *copiedURLTextField;

- (IBAction)orderFrontSettingsWindow:(id)sender;
- (IBAction)selectAppToUpload:(id)sender;

@end
