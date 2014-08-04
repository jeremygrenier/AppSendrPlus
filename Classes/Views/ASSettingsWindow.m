//
//  ASSettingsWindow.m
//  AppSendr+
//
//  Created by Jeremy GRENIER on 30/06/2014.
//  Copyright (c) 2014 AppSendr. All rights reserved.
//

#import "ASSettingsWindow.h"

#import "ASAppDelegate.h"

@implementation ASSettingsWindow

#pragma mark - Window Life

- (void)awakeFromNib
{
    NSInteger numDrops = [[NSUserDefaults standardUserDefaults] integerForKey:@"numDrops"];
    [self.numDropsSlider setFloatValue: numDrops];
    self.numDropsTextField.stringValue = [NSString stringWithFormat:@"%ld", numDrops];
}

#pragma mark - Custom Method

- (IBAction)numDropsSliderChanged:(id)sender
{
    NSInteger numDrops = [[NSUserDefaults standardUserDefaults] integerForKey:@"numDrops"];
    NSSlider *slider = (NSSlider *) sender;
    NSInteger value = slider.integerValue;
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:@"numDrops"];
        
    if ( numDrops != value ) { // added 1 more drop
        [[NSNotificationCenter defaultCenter] postNotificationName:ASResetMenuNotification object:nil];
    }
    
    NSString *str = [NSString stringWithFormat:@"%ld", value];
    self.numDropsTextField.stringValue = str;
}

@end
