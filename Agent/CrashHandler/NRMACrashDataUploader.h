//
//  NRMACrashDataUploader.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/18/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAConnection.h"

// Maximum number of launch cycles before a crash report is abandoned.
#define kNRMAMaxCrashUploadRetry 3

@interface NRMACrashDataUploader : NRMAConnection <NSURLSessionTaskDelegate>
{
    NSFileManager* _fileManager;
    NSString* _crashCollectorHost;
    BOOL _useSSL;
}

// Background URLSession — uploads survive app suspension. Exposed for test injection.
@property(strong) NSURLSession* uploadSession;

- (void) uploadCrashReports;

- (instancetype) initWithCrashCollectorURL:(NSString*)url
                          applicationToken:(NSString*)token
                     connectionInformation:(NRMAConnectInformation*)connectionInformation
                                    useSSL:(BOOL)useSSL;
@end

