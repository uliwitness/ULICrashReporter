//
//  AppDelegate.m
//  CrashTestApp
//
//  Created by Uli Kusterer on 14/05/16.
//  Copyright © 2016 Uli Kusterer. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSString	*	theCrashReporter = [[NSBundle mainBundle] pathForResource: @"CrashTestApp Crash Reporter" ofType: @"app"];
	[[NSWorkspace sharedWorkspace] launchApplication: theCrashReporter];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	NSURL	*	theCrashReporter = [[NSBundle mainBundle] URLForResource: @"CrashTestApp Crash Reporter" withExtension: @"app"];
	for( NSRunningApplication* app in [[NSWorkspace sharedWorkspace] runningApplications] )
	{
		if( [app.bundleURL isEqualTo: theCrashReporter] )
		{
			[app terminate];
			break;
		}
	}
}


-(IBAction) doCrash: (id)sender
{
	int	*	myInt = NULL;
	*myInt = 1234;
}

@end
