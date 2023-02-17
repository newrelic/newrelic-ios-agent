//
//  NRMACrashDataUploader.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/18/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAConnection.h"
#import "NRMACrashDataUploader.h"
#import "NRMAExceptionhandlerConstants.h"
#import "NRLogger.h"
#import "NewRelicAgentInternal.h"
#import "NRMAHarvestController.h"
#import "NRMATaskQueue.h"
#import "NRMASupportMetricHelper.h"

@implementation NRMACrashDataUploader

- (instancetype) initWithCrashCollectorURL:(NSString*)url
                          applicationToken:(NSString*)token
                     connectionInformation:(NRMAConnectInformation*)connectionInformation
                                    useSSL:(BOOL)useSSL
{
    self = [super init];
    if (self) {
        self.uploadSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

        _fileManager = [NSFileManager defaultManager];
        self.applicationToken = token;
        self.applicationVersion = connectionInformation.applicationInformation.appVersion;
        _crashCollectorHost = url;
        _useSSL = useSSL;
        _inFlightCount = 0;
    }
    return self;
}

- (NSArray*) crashReportURLs:(NSError* __autoreleasing*)error
{
    NSString* reportPath = [NSString stringWithFormat:@"%@/%@",NSTemporaryDirectory(),kNRMA_CR_ReportPath];
    BOOL isDir;

    // If the directory doesn't even exist we shouldn't call contentsOfDirectoryAtURL on it.
    if (![_fileManager fileExistsAtPath:reportPath isDirectory: &isDir]) {
        if (!isDir)
            return @[];
    }

    NSArray* fileList = [_fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:reportPath]
                                    includingPropertiesForKeys:nil
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles| NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                         error:error];

    NSMutableArray* crashReports = [NSMutableArray new];
    for (NSURL* url in fileList) {
        if ([url.pathExtension isEqualToString:kNRMA_CR_ReportExtension]) {
            [crashReports addObject:url];
        }
    }

    return crashReports;
}

- (void) uploadCrashReports
{
    if (_inFlightCount > 0) {
        NRLOG_VERBOSE(@"Crash Data Uploader already running");
        return;
    }
    NSError* error = nil;
    NSArray* reportURLs = [self crashReportURLs:&error];
    if ([reportURLs count] <= 0) {
        if (error) {
            NRLOG_VERBOSE(@"failed to fetch crash reports: %@",error.description);
        } else {
            NRLOG_VERBOSE(@"Currently no crash files to upload.");
        }
        return;
    }

    for (NSURL* fileURL in reportURLs) {

        [self uploadFileAtPath:fileURL];
    }
}

- (void) uploadFileAtPath:(NSURL*)path
{
    if (!_crashCollectorHost.length) {
        NRLOG_ERROR(@"NEWRELIC CRASH UPLOADER - Crash collector address was not set. Unable to upload crash.");
        return;
    }

    if (path == nil) {
        NRLOG_ERROR(@"NEWRELIC CRASH UPLOADER - CrashData path was not set. Unable to upload crash.");
        return;
    }

    // Start tracking file upload attempts.
    if (![self shouldUploadFileWithUniqueIdentifier:path.absoluteString]) {
        NRLOG_VERBOSE(@"NEWRELIC CRASH UPLOADER - Reached upload retry limit for a crash report. Removing crash report: %@",path.absoluteString);
        // Enqueue supportability metric "Supportability/AgentHealth/Crash/RemovedStale".
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityPrefix@"/Crash/RemoveStale"
                                                        value:@1
                                                        scope:nil]];
        [_fileManager removeItemAtURL:path error:nil];
        return;
    }
    // Get the size in bytes of the crash report to be uploaded via below uploadTaskWithRequest:fromFile call.
    __block NSData* reqData = [NSData dataWithContentsOfURL:path options:0 error:nil];
    NSURLRequest* request = [self buildPost];
    
    if ([reqData length] > kNRMAMaxPayloadSizeLimit) {
        NRLOG_ERROR(@"Unable to upload crash log because payload is larger than 1 MB, discarding crash report");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"mobile_crash"];
        // Remove the crash log even though we couldn't upload so we don't try every time.
        [self removeCrashLogAtpath:path];
        return;
    }

    _inFlightCount += 1;
    [[self.uploadSession uploadTaskWithRequest:request fromFile:path completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable responseError) {
        self->_inFlightCount -= 1;

        NRLOG_VERBOSE(@"NEWRELIC CRASH UPLOADER - Crash Upload Response: %@", response);
        if(responseError) {
            NRLOG_ERROR(@"NEWRELIC CRASH UPLOADER - Crash Upload Response Error: %@", responseError);
        }
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {

            unsigned long long requestLength = [reqData length];
            reqData = nil;

            if(((NSHTTPURLResponse*)response).statusCode == 200 || ((NSHTTPURLResponse*)response).statusCode == 500) {

                // Enqueue Data Usage Supportability Metric for /mobile_crash is request successful.
                [NRMASupportMetricHelper enqueueDataUseMetric:@"mobile_crash"
                                                         size:requestLength
                                                     received:response.expectedContentLength];

                [self removeCrashLogAtpath:path];
            } else {
                NRLOG_VERBOSE(@"NEWRELIC CRASH UPLOADER - failed to upload crash log: %@, to try again later.",path.path);
            }
        }
    }] resume];
}

- (void) removeCrashLogAtpath:(NSURL*) path {
    NSError* error = nil;
    //stop tracking the file's upload attempts.
    [self stopTrackingFileUploadWithUniqueIdentifier:path.absoluteString];
    BOOL didRemoveFile = [self->_fileManager removeItemAtURL:path error:&error];

    if (error) {
        NRLOG_ERROR(@"NEWRELIC CRASH UPLOADER - Failed to remove crash file :%@, %@",path.path, error.description);
    } else if (!didRemoveFile) {
        NRLOG_ERROR(@"NEWRELIC CRASH UPLOADER - Failed to remove crash file. Error unknown.");
    }
}

- (NSURLRequest*) buildPost {
    NSMutableURLRequest* request = [super newPostWithURI:[NSString stringWithFormat:@"%@%@/%@",_useSSL?@"https://":@"http://",_crashCollectorHost,kNRMA_CR_CrashCollectorPath]];

    return request;
}

- (void) stopTrackingFileUploadWithUniqueIdentifier:(NSString*)key {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:key];
    [defaults synchronize];
}

- (BOOL) shouldUploadFileWithUniqueIdentifier:(NSString*)key {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSNumber* value = [defaults objectForKey:key];
    if (value != nil) {
        value = @(value.integerValue + 1);
    } else {
        value = @1;
    }

    if (value.integerValue > kNRMAMaxCrashUploadRetry) {
        [self stopTrackingFileUploadWithUniqueIdentifier:key];

        
        return NO;
    }

    [defaults setObject:value forKey:key];
    [defaults synchronize];
    return YES;
}

@end
