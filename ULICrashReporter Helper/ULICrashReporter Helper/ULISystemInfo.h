//
//  ULISystemInfo.h
//  ULISystemInfo
//
//  Created by Uli Kusterer on 23.09.04.
//  Copyright 2004 M. Uli Kusterer. Uli Kusterer
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

#import <Foundation/Foundation.h>

#if __cplusplus
extern "C" {
#endif


unsigned	ULIPhysicalRAMSize(void);					// RAM Size in MBs.
NSString*	ULISystemVersionString(void);				// System version as a string MM.m.b
unsigned	ULIClockSpeed(void);							// CPU speed in MHz.
unsigned	ULICountCores(void);							// Number of CPU cores. This is always >= number of CPUs.
NSString*	ULIMachineName(void);						// Name of Mac model, as best as we can determine.
NSString*	ULICPUName(void);							// Same as ULIAutoreleasedCPUName( NO );
NSString*	ULIAutoreleasedCPUName( BOOL dontCache );	// Returns CPU name, e.g. "Intel(r) Celeron(tm) 1234  U8888  @ 1.6GHz" etc. If dontCache is YES, this will look up the name anew each time, if NO it will cache the name for subsequent calls.
void		ULIGetSystemVersionComponents( SInt32* outMajor, SInt32* outMinor, SInt32* outBugfix );	// System version as the separate components (Major.Minor.Bugfix).

#if __cplusplus
}
#endif

