//
//  IPADropView.h
//
//  Created by Nolan Brown on 5/12/11.
//  Copyright 2013 AppSendr. See LICENSE.txt for Licensing Infomation
//

#import <Cocoa/Cocoa.h>

@protocol ASIPADropViewDelegate;

@interface ASIPADropView : NSView <NSMenuDelegate>
{
	BOOL _isDragged;
    BOOL _highlight;
	NSImageView *_imageView;
    BOOL _success;
    BOOL _error;
}

@property (nonatomic, weak) IBOutlet id<ASIPADropViewDelegate> delegate;
@property (weak) NSStatusItem *statusItem;
@property (assign) CGFloat progress;

- (CGPoint)pointForAttachedWindow;
- (void)updateViewForProgress:(CGFloat)progress;
- (void)flashViewForSuccess:(BOOL)success;

@end

@protocol ASIPADropViewDelegate <NSObject>

- (void)viewRecievedFileAtPath:(NSString *)path;

@end
