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

@class NRMARetryingHTTPClient;

@interface NRMACrashDataUploader : NRMAConnection
{
    NSFileManager* _fileManager;
    NSString* _crashCollectorHost;
    BOOL _useSSL;
}

// Retrying HTTP client — exposed for test injection.
@property(strong) NRMARetryingHTTPClient* httpClient;

- (void) uploadCrashReports;

- (instancetype) initWithCrashCollectorURL:(NSString*)url
                          applicationToken:(NSString*)token
                     connectionInformation:(NRMAConnectInformation*)connectionInformation
                                    useSSL:(BOOL)useSSL;
@end

