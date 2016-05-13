//
//  AppDelegate.m
//  ULICrashReporter Helper
//
//  Created by Uli Kusterer on 14/05/16.
//  Copyright © 2016 Uli Kusterer. All rights reserved.
//

#import "AppDelegate.h"
#import "ULICrashReporter.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//(*(int*)0) = 1234;
	
	ULICrashReporterCheckForCrash();
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

@end
