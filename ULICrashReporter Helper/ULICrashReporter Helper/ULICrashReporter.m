//
//  UKCrashReporter.m
//  NiftyFeatures
//
//  Created by Uli Kusterer on Sat Feb 04 2006.
//  Copyright (c) 2006 Uli Kusterer.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	   1. The origin of this software must not be misrepresented; you must not
//	   claim that you wrote the original software. If you use this software
//	   in a product, an acknowledgment in the product documentation would be
//	   appreciated but is not required.
//
//	   2. Altered source versions must be plainly marked as such, and must not be
//	   misrepresented as being the original software.
//
//	   3. This notice may not be removed or altered from any source
//	   distribution.
//

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "UKCrashReporter.h"
#import "UKSystemInfo.h"
#import <AddressBook/AddressBook.h>


NSString*	UKCrashReporterFindTenFiveCrashReportPath( NSString* appName, NSString* crashLogsFolder );


static UKCrashReporter	*	sCurrentCrashReporter = nil;

// -----------------------------------------------------------------------------
//	UKCrashReporterCheckForCrash:
//		This submits the crash report to a CGI form as a POST request by
//		passing it as the request variable "crashlog".
//	
//		KNOWN LIMITATION:	If the app crashes several times in a row, only the
//							last crash report will be sent because this doesn't
//							walk through the log files to try and determine the
//							dates of all reports.
//
//		This is written so it works back to OS X 10.2, or at least gracefully
//		fails by just doing nothing on such older OSs. This also should never
//		throw exceptions or anything on failure. This is an additional service
//		for the developer and *mustn't* interfere with regular operation of the
//		application.
// -----------------------------------------------------------------------------

void	UKCrashReporterCheckForCrash( void )
{
	NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
	
	NS_DURING
		// Try whether the classes we need to talk to the CGI are present:
		Class			NSMutableURLRequestClass = NSClassFromString( @"NSMutableURLRequest" );
		Class			NSURLConnectionClass = NSClassFromString( @"NSURLConnection" );
		if( NSMutableURLRequestClass == Nil || NSURLConnectionClass == Nil )
		{
			[pool release];
			NS_VOIDRETURN;
		}
		
		SInt32	sysvMajor = 0, sysvMinor = 0, sysvBugfix = 0;
		UKGetSystemVersionComponents( &sysvMajor, &sysvMinor, &sysvBugfix );
		BOOL	isTenSixOrBetter = (sysvMajor == 10 && sysvMinor >= 6) || sysvMajor > 10;
		BOOL	isTenFiveOrBetter = (sysvMajor == 10 && sysvMinor >= 5) || sysvMajor > 10;
	
		// Get the log file, its last change date and last report date:
		NSString*		appName = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleExecutable"];
		NSString*		crashLogsFolder = [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
		NSString*		diagnosticReportsFolder = [@"~/Library/Logs/DiagnosticReports/" stringByExpandingTildeInPath];
		NSString*		crashLogName = [appName stringByAppendingString: @".crash.log"];
		NSString*		crashLogPath = nil;
		if( isTenSixOrBetter )
			crashLogPath = UKCrashReporterFindTenFiveCrashReportPath( appName, diagnosticReportsFolder );
		else if( isTenFiveOrBetter )
			crashLogPath = UKCrashReporterFindTenFiveCrashReportPath( appName, crashLogsFolder );
		else
			crashLogPath = [crashLogsFolder stringByAppendingPathComponent: crashLogName];
		if( !crashLogPath )
			return;	// No crash, or at least we didn't find one.
	
		NSDictionary*	fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath: crashLogPath error: NULL];
		NSDate*			lastTimeCrashLogged = (fileAttrs == nil) ? nil : [fileAttrs fileModificationDate];
		NSTimeInterval	lastCrashReportInterval = [[NSUserDefaults standardUserDefaults] floatForKey: @"UKCrashReporterLastCrashReportDate"];
		NSDate*			lastTimeCrashReported = [NSDate dateWithTimeIntervalSince1970: lastCrashReportInterval];
		
		if( lastTimeCrashLogged )	// We have a crash log file and its mod date? Means we crashed sometime in the past.
		{
			// If we never before reported a crash or the last report lies before the last crash:
			if( [lastTimeCrashReported compare: lastTimeCrashLogged] == NSOrderedAscending )
			{
				// Fetch the newest report from the log:
				NSString*			crashLog = [NSString stringWithContentsOfFile: crashLogPath encoding: NSUTF8StringEncoding error: nil];	// +++ Check error.
				NSArray*			separateReports = [crashLog componentsSeparatedByString: @"\n\n**********\n\n"];
				NSString*			currentReport = [separateReports count] > 0 ? [separateReports objectAtIndex: [separateReports count] -1] : @"*** Couldn't read Report ***";	// 1 since report 0 is empty (file has a delimiter at the top).
				unsigned			numCores = UKCountCores();
				NSString*			numCPUsString = (numCores == 1) ? @"" : [NSString stringWithFormat: @"%dx ",numCores];
				
				// Create a string containing Mac and CPU info, crash log and prefs:
				currentReport = [NSString stringWithFormat:
									@"Model: %@\nCPU Speed: %@%.2f GHz\n%@\n\nPreferences:\n%@",
									UKMachineName(), numCPUsString, ((float)UKClockSpeed()) / 1000.0f,
									currentReport,
									[[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]]];
				
				// Now show a crash reporter window so the user can edit the info to send:
				[[UKCrashReporter alloc] initWithLogString: currentReport];
			}
		}
	NS_HANDLER
		NSLog(@"Error during check for crash: %@",localException);
	NS_ENDHANDLER
	
	[pool release];
}

NSString*	UKCrashReporterFindTenFiveCrashReportPath( NSString* appName, NSString* crashLogsFolder )
{
	NSDirectoryEnumerator*	enny = [[NSFileManager defaultManager] enumeratorAtPath: crashLogsFolder];
	NSString*				currName = nil;
	NSString*				crashLogPrefix = [NSString stringWithFormat: @"%@_",appName];
	NSString*				crashLogSuffix = @".crash";
	NSString*				foundName = nil;
	NSDate*					foundDate = nil;
	
	// Find the newest of our crash log files:
	while(( currName = [enny nextObject] ))
	{
		if( [currName hasPrefix: crashLogPrefix] && [currName hasSuffix: crashLogSuffix] )
		{
			NSDate*	currDate = [[enny fileAttributes] fileModificationDate];
			if( foundName )
			{
				if( [currDate isGreaterThan: foundDate] )
				{
					foundName = currName;
					foundDate = currDate;
				}
			}
			else
			{
				foundName = currName;
				foundDate = currDate;
			}
		}
	}
	
	if( !foundName )
		return nil;
	else
		return [crashLogsFolder stringByAppendingPathComponent: foundName];
}


NSString*	gCrashLogString = nil;


@implementation UKCrashReporter

-(id)	initWithLogString: (NSString*)theLog
{
	// In super init the awakeFromNib method gets called, so we can not
	//	use ivars to transfer the log, and use a global instead:
	gCrashLogString = [theLog retain];
	
	self = [super init];
	return self;
}


-(id)	init
{
	self = [super init];
	if( self )
	{
		feedbackMode = YES;
	}
	return self;
}


-(void)	awakeFromNib
{
	// Insert the app name into the explanation message:
	NSString*			appName = [[NSFileManager defaultManager] displayNameAtPath: [[NSBundle mainBundle] bundlePath]];
	NSMutableString*	expl = nil;
	if( gCrashLogString )
		expl = [[[explanationField stringValue] mutableCopy] autorelease];
	else
		expl = [[NSLocalizedStringFromTable(@"FEEDBACK_EXPLANATION_TEXT",@"UKCrashReporter",@"") mutableCopy] autorelease];
	[expl replaceOccurrencesOfString: @"%%APPNAME" withString: appName
				options: 0 range: NSMakeRange(0, [expl length])];
	[explanationField setStringValue: expl];
	
	// Insert user name and e-mail address into the information field:
	NSMutableString*	userMessage = nil;
	if( gCrashLogString )
		userMessage = [[[informationField string] mutableCopy] autorelease];
	else
		userMessage = [[NSLocalizedStringFromTable(@"FEEDBACK_MESSAGE_TEXT",@"UKCrashReporter",@"") mutableCopy] autorelease];
	[userMessage replaceOccurrencesOfString: @"%%LONGUSERNAME" withString: NSFullUserName()
				options: 0 range: NSMakeRange(0, [userMessage length])];
	ABPerson*		myself = [[ABAddressBook sharedAddressBook] me];
	ABMultiValue*	emailAddresses = [myself valueForProperty: kABEmailProperty];
	NSString*		emailAddr = NSLocalizedStringFromTable(@"MISSING_EMAIL_ADDRESS",@"UKCrashReporter",@"");
	if( emailAddresses )
	{
		NSString*		defaultKey = [emailAddresses primaryIdentifier];
		if( defaultKey )
		{
			NSUInteger	defaultIndex = [emailAddresses indexForIdentifier: defaultKey];
			if( defaultIndex != NSNotFound )
				emailAddr = [emailAddresses valueAtIndex: defaultIndex];
		}
	}
	[userMessage replaceOccurrencesOfString: @"%%EMAILADDRESS" withString: emailAddr
				options: 0 range: NSMakeRange(0, [userMessage length])];
	[informationField setString: userMessage];
	
	// Show the crash log to the user:
	if( gCrashLogString )
	{
		[crashLogField setString: gCrashLogString];
		[gCrashLogString release];
		gCrashLogString = nil;
	}
	else
	{
		[remindButton setHidden: YES];
		
		NSInteger		itemIndex = [switchTabView indexOfTabViewItemWithIdentifier: @"de.zathras.ukcrashreporter.crashlog-tab"];
		NSTabViewItem*	crashLogItem = [switchTabView tabViewItemAtIndex: itemIndex];
		unsigned		numCores = UKCountCores();
		NSString*		numCPUsString = (numCores == 1) ? @"" : [NSString stringWithFormat: @"%dx ",numCores];
		[crashLogItem setLabel: NSLocalizedStringFromTable(@"SYSTEM_INFO_TAB_NAME",@"UKCrashReporter",@"")];
		
		NSString*	systemInfo = [NSString stringWithFormat: @"Application: %@ %@\nModel: %@\nCPU Speed: %@%.2f GHz\nCPU: %@\nRAM: %u GB\nSystem Version: %@\n\nPreferences:\n%@",
									appName, [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"],
									UKMachineName(), numCPUsString, ((float)UKClockSpeed()) / 1000.0f,
									UKAutoreleasedCPUName(NO),
									(UKPhysicalRAMSize() / 1024U),
									UKSystemVersionString(),
									[[NSUserDefaults standardUserDefaults] persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]]];
		[crashLogField setString: systemInfo];
	}
	
	// Show the window:
	[reportWindow makeKeyAndOrderFront: self];
}


-(NSWindow*)	window
{
	return reportWindow;
}


-(IBAction)	sendCrashReport: (id)sender
{
	NSString            *boundary = @"0xKhTmLbOuNdArY";
	NSMutableString*	crashReportString = [NSMutableString string];
	[crashReportString appendString: [informationField string]];
	[crashReportString appendString: @"\n==========\n"];
	[crashReportString appendString: [crashLogField string]];
	[crashReportString replaceOccurrencesOfString: boundary withString: @"USED_TO_BE_KHTMLBOUNDARY" options: 0 range: NSMakeRange(0, [crashReportString length])];
	NSData*				crashReport = [crashReportString dataUsingEncoding: NSUTF8StringEncoding];
	
	// Prepare a request:
	NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: NSLocalizedStringFromTable( @"CRASH_REPORT_CGI_URL", @"UKCrashReporter", @"" )]];
	NSString            *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
	NSString			*agent = @"UKCrashReporter";
	
	// Add form trappings to crashReport:
	NSData*			header = [[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"crashlog\"\r\n\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData*	formData = [[header mutableCopy] autorelease];
	[formData appendData: crashReport];
	[formData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	
	// setting the headers:
	[postRequest setHTTPMethod: @"POST"];
	[postRequest setValue: contentType forHTTPHeaderField: @"Content-Type"];
	[postRequest setValue: agent forHTTPHeaderField: @"User-Agent"];
	NSString *contentLength = [NSString stringWithFormat:@"%lu", [formData length]];
	[postRequest setValue: contentLength forHTTPHeaderField: @"Content-Length"];
	[postRequest setHTTPBody: formData];
	
	// Go into progress mode and kick off the HTTP post:
	[progressIndicator startAnimation: self];
	[sendButton setEnabled: NO];
	[remindButton setEnabled: NO];
	[discardButton setEnabled: NO];
	
	NSURLSession		 *	session = [NSURLSession sharedSession];
	NSURLSessionDataTask *	theTask = [session dataTaskWithRequest: postRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		// Now that we successfully sent this crash, don't report it again:
		if( !feedbackMode )
		{
			[[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: @"UKCrashReporterLastCrashReportDate"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		
		[self performSelectorOnMainThread: @selector(showFinishedMessage:) withObject: error waitUntilDone: NO];
	}];
	[theTask resume];
}


-(IBAction)	remindMeLater: (id)sender
{
	[reportWindow orderOut: self];
	[sCurrentCrashReporter autorelease];
	sCurrentCrashReporter = nil;
}


-(IBAction)	discardCrashReport: (id)sender
{
	// Remember we already did this crash, so we don't ask twice:
	if( !feedbackMode )
	{
		[[NSUserDefaults standardUserDefaults] setFloat: [[NSDate date] timeIntervalSince1970] forKey: @"UKCrashReporterLastCrashReportDate"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	[reportWindow orderOut: self];
	[sCurrentCrashReporter autorelease];
	sCurrentCrashReporter = nil;
}


-(void)	showFinishedMessage: (NSError*)errMsg
{
	if( errMsg )
	{
		NSString*		errTitle = nil;
		if( feedbackMode )
			errTitle = NSLocalizedStringFromTable( @"COULDNT_SEND_FEEDBACK_ERROR",@"UKCrashReporter",@"");
		else
			errTitle = NSLocalizedStringFromTable( @"COULDNT_SEND_CRASH_REPORT_ERROR",@"UKCrashReporter",@"");
		
		NSAlert	*	theAlert = [[NSAlert new] autorelease];
		theAlert.messageText = errTitle;
		theAlert.informativeText = [errMsg localizedDescription];
		[theAlert addButtonWithTitle: NSLocalizedStringFromTable( @"COULDNT_SEND_CRASH_REPORT_ERROR_OK",@"UKCrashReporter",@"")];
	}
	
	[reportWindow orderOut: self];
	[sCurrentCrashReporter autorelease];
	sCurrentCrashReporter = nil;
}

@end


@implementation UKFeedbackProvider

-(IBAction) orderFrontFeedbackWindow: (id)sender
{
	if( sCurrentCrashReporter )
		[sCurrentCrashReporter.window makeKeyAndOrderFront: self];
	else
		sCurrentCrashReporter = [[UKCrashReporter alloc] init];
}


-(IBAction) orderFrontBugReportWindow: (id)sender
{
	if( sCurrentCrashReporter )
		[sCurrentCrashReporter.window makeKeyAndOrderFront: self];
	else
		sCurrentCrashReporter = [[UKCrashReporter alloc] init];
}

@end