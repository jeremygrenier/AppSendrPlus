//
//  ASAppDelegate.m
//  AppSendr
//
//  Created by Nolan Brown on 4/10/12.
//  Modifed by Jeremy Grenier on 6/29/14.
//  Copyright (c) 2013 AppSendr. See LICENSE.txt for Licensing Infomation
//

#import "ASAppDelegate.h"
#import "ASApp.h"
#import "ASAPIClient.h"
#import "NSFileManager+DirectoryLocations.h"
#import "NSImage+AppSendr.h"
#import "NSWindow+DPAdditions.h"

NSString * const ASResetMenuNotification = @"com.jgrenier.appsendrplus.ASResetMenuNotification";

NSString *ASToolbarGeneralSettingsItemIdentifier = @"ASToolbarGeneralSettingsItem";
NSString *ASToolbarAdvancedSettingsItemIdentifier = @"ASToolbarAdvancedSettingsItem";

typedef enum StatusItemState {
    StatusItemOK = 1,
    StatusItemDisabled = 2,
    StatusItemUploading = 3
} ASStatusItemState;


@implementation ASAppDelegate

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ASResetMenuNotification object:nil];

    _menuItems = nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if ( ![[NSUserDefaults standardUserDefaults] objectForKey:@"numDrops"] )
        [[NSUserDefaults standardUserDefaults] setInteger:7 forKey:@"numDrops"];

    if ( ![[NSUserDefaults standardUserDefaults] objectForKey:@"popupDuration"] )
        [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:@"popupDuration"];

    _defaults = [NSUserDefaults standardUserDefaults];
    _menuItems = [[NSMutableArray alloc] init];

    [self setStatusItemState:StatusItemOK];
    NSArray *apps = [self recentlyOpenedApps];
    for ( ASApp *app in apps ) {
        [self addAppToStatusMenu:app];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetMenuItems) name:ASResetMenuNotification object:nil];
}

- (IBAction)displayViewForGeneralSettings:(id)sender
{
	if ( self.generalSettingsView && [self.window contentView] != self.generalSettingsView )
		[self.window setContentView:self.generalSettingsView display:YES animate:YES];
}

- (IBAction)displayViewForAdvancedSettings:(id)sender
{
	if ( self.advancedSettingsView && [self.window contentView] != self.advancedSettingsView )
		[self.window setContentView:self.advancedSettingsView display:YES animate:YES];
}

- (IBAction)orderFrontSettingsWindow:(id)sender
{
	if ( ![NSApp isActive] )
		[NSApp activateIgnoringOtherApps:YES];
	[self.window makeKeyAndOrderFront:sender];
}

- (IBAction)selectAppToUpload:(id)sender
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setTitle:@"Choose an .app, .ipa, or .apk"];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
    [panel setAllowedFileTypes:@[@"ipa",@"app",@"apk"]];

    NSString *startDir = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastPathSelected"];
    if(startDir == nil)
        startDir = NSHomeDirectory();

    [panel setDirectoryURL:[NSURL URLWithString:startDir]];

    // This method displays the panel and returns immediately.
    // The completion handler is called when the user selects an
    // item or cancels the panel.
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [panel URLs][0];
            if([theDoc isFileURL]) {
                NSString *path = [theDoc path];
                [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"lastPathSelected"];
                [self processFileAtPath:path];
            }
        }
        // Balance the earlier retain call.
    }];
}

#pragma mark - Drop View Delegate

- (BOOL)connectToParse
{
    static BOOL connected = NO;
    
    if ( !connected ) {
        NSString *parseApplicationId = [[NSUserDefaults standardUserDefaults] objectForKey:@"parseApplicationId"];
        NSString *parseClientId = [[NSUserDefaults standardUserDefaults] objectForKey:@"parseClientId"];
        
        if ( !parseApplicationId && !parseClientId ) {
            ASLog(@"You have to set your ParseApplicationId and ParseClientId.");
        }
        else {
            [Parse setApplicationId:parseApplicationId clientKey:parseClientId];
            connected = YES;
        }
    }
    return connected;
}

- (void)viewRecievedFileAtPath:(NSString *)path
{
    [self processFileAtPath:path];
}

- (void)processFileAtPath:(NSString *)path
{
    [ASApp appWithSourcePath:path proccessingFinished:^(ASApp *app, BOOL success) {
        [self uploadApp:app];
    }];
}

- (void)uploadParseWithApp:(ASApp *)app
{
    if ( ![self connectToParse] )
        return;
    
    PFQuery *query = [PFQuery queryWithClassName:@"App"];

    [query whereKey:@"name" equalTo:app.name];

    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        if ( error.code == 101 ) {
            object = [PFObject objectWithClassName:@"App"];
            object[@"name"] = app.name;
            object[@"identifier"] = app.identifier;

            if ( app.icon ) {
                NSData *iconData = [app.icon.largeImage TIFFRepresentation];
                object[@"icon"] = [PFFile fileWithData:iconData];
            }
        }

        PFObject *bundle = [PFObject objectWithClassName:@"Bundle"];
        bundle[@"version"] = app.version;
        bundle[@"otaURL"] = [app.otaURL absoluteString];
        bundle[@"otaId"] = app.otaId;
        bundle[@"deleteToken"] = app.deleteToken;

        [bundle saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if ( succeeded ) {
                PFRelation * relation = [object relationforKey:@"bundles"];
                [relation addObject:bundle];
                
                [object saveInBackground];
            }
        }];
        
    }];
}

- (void)uploadApp:(ASApp *)app
{
    [[ASAPIClient sharedClient] uploadApp:app
                     withProgressCallback:^(CGFloat progress) {
                         if ( (progress * 100) < 80 )
                             [_dropView updateViewForProgress:(progress * 100)];
                     }
                                 finished:^(BOOL successful, id response) {
                                     if ( successful ) {
                                         NSDictionary *jsonResponse = (NSDictionary *) response;
                                         
                                         if ( !jsonResponse[@"error"] ) {
                                             NSString *otaURLStr = jsonResponse[@"url"];
                                             NSString *otaId = jsonResponse[@"id"];
                                             NSString *deleteToken = jsonResponse[@"token"];
                                             
                                             app.otaURL = [NSURL URLWithString:otaURLStr];
                                             app.otaId = otaId;
                                             app.deleteToken = deleteToken;
                                             ASLog(@"app.otaURL %@",app.otaURL);
                                             app.addedAt = [NSDate date];
                                             [app copyURLToClipboard];
                                             [self showCopiedURL:otaURLStr];
                                         }
                                         
                                         [_dropView flashViewForSuccess:YES];
                                         [_dropView updateViewForProgress:100];
                                         
                                         [self addAppToStatusMenu:app];
                                         
                                         [app save];
                                         
                                         _reloadOpenApps = YES;
                                         [self recentlyOpenedApps];
                                         
                                         [self uploadParseWithApp:app];
                                     }
                                     else {
                                         [app destroy];
                                         [_dropView flashViewForSuccess:NO];
                                         [_dropView updateViewForProgress:100];
                                     }
                                 }];
}

- (void)addAppToStatusMenu:(ASApp *)app
{
    NSString *name = [NSString stringWithFormat:@"%@ (%@)",app.name,app.version];
    
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""]; //@selector(openInBrowser:)
    
    [item setRepresentedObject:app.guid];
    
    if ( app.icon.smallImage ) {
        [item setImage:app.icon.smallImage];
        
    }
    else if ( app.icon.image ) {
        NSImage *image = [NSImage scaleImage:app.icon.image toSize:CGSizeMake(20, 20) proportionally:YES];
        [item setImage:image];
    }

    NSMenu *submenu = [[NSMenu alloc] initWithTitle:name];
    [submenu addItemWithTitle:[NSString stringWithFormat:@"Dropped on %@",[app formattedAddedAt]] action:nil keyEquivalent:@""];

    if ( app.otaURL ) {
        [submenu addItemWithTitle:@"Copy link to Clipboard" action:@selector(copyLinkToClipboard:) keyEquivalent:@""];
    }
    [submenu addItemWithTitle:@"View in Browser" action:@selector(openInBrowser:) keyEquivalent:@""];
    [submenu addItemWithTitle:@"Open in Finder" action:@selector(openInFinder:) keyEquivalent:@""];

    [submenu addItemWithTitle:@"Delete" action:@selector(deleteFromCache:) keyEquivalent:@""];

    [_menuItems insertObject:item atIndex:0];

    [self.statusItemMenu insertItem:item atIndex:3];
    [self.statusItemMenu setSubmenu:submenu forItem:item];
}

- (void)openInBrowser:(id)sender
{
    NSMenuItem *item = (NSMenuItem *) sender;
    NSMenuItem *parent = [item parentItem];
    NSString *guid = (NSString *)[parent representedObject];
    ASApp *app = [ASApp appWithGUID:guid];
    if ( app ) {
        if ( app.otaURL ) {
            [[NSWorkspace sharedWorkspace] openURL:app.otaURL];
        }
    }
}

- (void)copyLinkToClipboard:(id)sender
{
    NSMenuItem *item = (NSMenuItem *) sender;
    NSMenuItem *parent = [item parentItem];
    NSString *guid = (NSString *)[parent representedObject];
    ASApp *app = [ASApp appWithGUID:guid];
    if ( app ) {
        [app copyURLToClipboard];
        [self showCopiedURL:[app.otaURL absoluteString]];
    }
}

- (void)openInFinder:(id)sender
{
    NSMenuItem *item = (NSMenuItem *) sender;
    NSMenuItem *parent = [item parentItem];
    NSString *guid = (NSString *)[parent representedObject];
    ASApp *app = [ASApp appWithGUID:guid];
    
    if ( app ) {
        [[NSWorkspace sharedWorkspace] openFile:app.cachePath];
    }
}

- (void)destroyParseWithApp:(ASApp *)app
{
    if ( ![self connectToParse] )
        return;
    
    PFQuery *query = [PFQuery queryWithClassName:@"App"];
    
    [query whereKey:@"name" equalTo:app.name];
    
    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        if ( !error ) {
            
            PFRelation *relation = [object relationForKey:@"bundles"];
            PFQuery *query = [relation query];
            
            [query findObjectsInBackgroundWithBlock:^(NSArray *bundles, NSError *error) {
                if ( !error ) {
                    for ( PFObject *bundle in bundles ) {
                        [bundle deleteInBackground];
                    }
                    [object deleteInBackground];
                }
            }];
            
        }
    }];
}

- (void)deleteFromCache:(id)sender
{
    NSMenuItem *item = (NSMenuItem *) sender;
    NSMenuItem *parent = [item parentItem];
    NSString *guid = (NSString *)[parent representedObject];
    ASApp *app = [ASApp appWithGUID:guid];
    
    [[ASAPIClient sharedClient] destroyApp:app finished:^(BOOL successful) {
        ASLog(@"Deleted: %d",successful);
        [self destroyParseWithApp:app];
    }];
    
    [app destroy];
    
    [self.statusItemMenu removeItem:parent];
    
    [_menuItems removeObject:item];
    
    _reloadOpenApps = YES;
    [self recentlyOpenedApps];
}


#pragma mark -
#pragma mark NSToolbar delegate methods


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)_toolbar
{
	return @[ASToolbarGeneralSettingsItemIdentifier,
             ASToolbarAdvancedSettingsItemIdentifier,
             NSToolbarFlexibleSpaceItemIdentifier,
             NSToolbarSpaceItemIdentifier,
             NSToolbarSeparatorItemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)_toolbar
{
	return @[ASToolbarGeneralSettingsItemIdentifier,
             ASToolbarAdvancedSettingsItemIdentifier];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *item = nil;
	if ( itemIdentifier == ASToolbarGeneralSettingsItemIdentifier ) {
		item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		[item setImage:[NSImage imageNamed:@"NSPreferencesGeneral"]];
		[item setLabel:@"General"];
		[item setToolTip:@"General settings"];
		[item setTarget:self];
		[item setAction:@selector(displayViewForGeneralSettings:)];
        if ( !toolbar.selectedItemIdentifier ) {
            toolbar.selectedItemIdentifier = ASToolbarGeneralSettingsItemIdentifier;
        }
	}
	else if ( itemIdentifier == ASToolbarAdvancedSettingsItemIdentifier ) {
		item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		[item setImage:[NSImage imageNamed:@"NSAdvanced"]];
		[item setLabel:@"Advanced"];
		[item setToolTip:@"You probably don't need to change these things in here"];
		[item setTarget:self];
		[item setAction:@selector(displayViewForAdvancedSettings:)];
	}
    
	return item;
}

#pragma mark - Private Methods

- (void)setStatusItemState:(ASStatusItemState)state
{
	if (!_statusItem) {
        _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        [_statusItem setHighlightMode:YES];
        [_statusItem setEnabled:YES];
        [_statusItem setMenu:self.statusItemMenu];
        
        if ( !_dropView ) {
            _dropView = [[ASIPADropView alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)];
            [_dropView setMenu:self.statusItemMenu];
            [_dropView setStatusItem:_statusItem];
            _dropView.delegate = self;
        }
        [_statusItem setView:_dropView];
	}
    
    switch (state) {
        case StatusItemOK:
            break;
            
        default:
            break;
    }
}

- (void)showCopiedURL:(NSString *)url
{
    [self closeCopiedURLPopup];
    
    CGPoint p = CGPointMake([_dropView pointForAttachedWindow].x - 32, [_dropView pointForAttachedWindow].y);
    // Attach/detach window.
    _urlCopiedWindow = [[MAAttachedWindow alloc] initWithView:self.copiedURLView
                                              attachedToPoint:p
                                                     inWindow:nil
                                                       onSide:MAPositionBottom
                                                   atDistance:5.0];
    //[self.copiedURLTextField setTextColor:[urlCopiedWindow_ borderColor]];
    [self.copiedURLTextField setStringValue:[NSString stringWithFormat:@"%@ copied!",url]];
    [_urlCopiedWindow makeKeyAndOrderFront:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:nil];
    
    CGFloat duration = [[NSUserDefaults standardUserDefaults] floatForKey:@"popupDuration"];
    
    [self performSelector:@selector(closeCopiedURLPopup) withObject:nil afterDelay:duration];
}

- (void)closeCopiedURLPopup
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidResignKeyNotification
                                                  object:nil];
    
    if ( _urlCopiedWindow ) {
        [_urlCopiedWindow orderOut:self];
        _urlCopiedWindow = nil;
    }
}

- (void)windowDidResignKey:(NSNotification *)note
{
    [self closeCopiedURLPopup];
}

- (void)removeLastMenuItem
{
    [self.statusItemMenu removeItem:[_menuItems lastObject]];
    [_menuItems removeLastObject];
}

- (void)addNextMenuItem
{
    NSInteger size = [_menuItems count];
    if ( size < [_orderedApps count] ) {
        ASApp *app = _orderedApps[size+1];
        [self addAppToStatusMenu:app];
    }
}

- (void)resetMenuItems
{
    for ( NSMenuItem *item in _menuItems ) {
        if ( [self.statusItemMenu indexOfItem:item] >= 0 )
            [self.statusItemMenu removeItem:item];
    }
    
    [_menuItems removeAllObjects];
    
    NSArray *apps = [self recentlyOpenedApps];
    for ( ASApp *app in apps ) {
        [self addAppToStatusMenu:app];
    }
}

- (NSArray *)recentlyOpenedApps
{
    if ( _orderedApps && !_reloadOpenApps ) {
        NSInteger numDrops = [[NSUserDefaults standardUserDefaults] integerForKey:@"numDrops"];
        if ( [_orderedApps count] > numDrops + 1 ) {
            NSInteger len = [_orderedApps count];
            return [_orderedApps objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(len-numDrops, numDrops)]];
        }
        return _orderedApps;
    }
    
    NSMutableArray *apps = [NSMutableArray array];
    
    NSString *caches = [[NSFileManager defaultManager] cachesDirectory];
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:caches];
    
    for ( NSString *filename in fileEnumerator ) {
        NSString *dir = [caches stringByAppendingPathComponent:filename];
        BOOL isDir = NO;
        if ( [[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] ) {
            if ( isDir ) {
                NSString *appFile = [dir stringByAppendingPathComponent:kASFileName];
                ASApp *app = [ASApp loadFromDisk:appFile];
                if ( app ) {
                    [apps addObject:app];
                }
            }
        }
    }
    
    NSArray *sortedApps;
    sortedApps = [apps sortedArrayUsingComparator:^(id a, id b) {
        NSDate *first = [(ASApp*)a addedAt];
        NSDate *second = [(ASApp*)b addedAt];
        
        return [first compare:second];
    }];
    if ( _orderedApps ) {
        _orderedApps = nil;
    }
    _reloadOpenApps = NO;
    _orderedApps = sortedApps ;
    
    return [self recentlyOpenedApps];
}

@end
