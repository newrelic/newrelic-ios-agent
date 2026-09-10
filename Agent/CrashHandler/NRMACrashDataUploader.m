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
#import <NewRelic/NewRelic-Swift.h>

static int __NRMACrashDataUploaderInProgressRequestCount = 0;

@implementation NRMACrashDataUploader

+ (int) inProgressRequestCount {
    return __NRMACrashDataUploaderInProgressRequestCount;
}

- (instancetype) initWithCrashCollectorURL:(NSString*)url
                          applicationToken:(NSString*)token
                     connectionInformation:(NRMAConnectInformation*)connectionInformation
                                    useSSL:(BOOL)useSSL
{
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        self.applicationToken   = token;
        self.applicationVersion = connectionInformation.applicationInformation.appVersion;
        _crashCollectorHost     = url;
        _useSSL                 = useSSL;

        self.httpClient = [[NRMARetryingHTTPClient alloc] init];
    }
    return self;
}

- (NSArray*) crashReportURLs:(NSError* __autoreleasing*)error
{
    NSString* reportPath = [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), kNRMA_CR_ReportPath];
    BOOL isDir;
    if (![_fileManager fileExistsAtPath:reportPath isDirectory:&isDir]) {
        if (!isDir) return @[];
    }

    NSArray* fileList = [_fileManager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:reportPath]
                                    includingPropertiesForKeys:nil
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                               |NSDirectoryEnumerationSkipsPackageDescendants
                                                               |NSDirectoryEnumerationSkipsSubdirectoryDescendants
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
    if (__NRMACrashDataUploaderInProgressRequestCount > 0) {
        return;
    }
    NSError* error = nil;
    NSArray* reportURLs = [self crashReportURLs:&error];
    if (reportURLs.count == 0) {
        if (error) {
            NRLOG_AGENT_VERBOSE(@"failed to fetch crash reports: %@", error.description);
        } else {
            NRLOG_AGENT_VERBOSE(@"Currently no crash files to upload.");
        }
        return;
    }
    for (NSURL* fileURL in reportURLs) {
        __NRMACrashDataUploaderInProgressRequestCount++;
        [self uploadFileAtPath:fileURL];
    }
}

- (void) uploadFileAtPath:(NSURL*)path
{
    if (!_crashCollectorHost.length) {
        NRLOG_AGENT_ERROR(@"NEWRELIC CRASH UPLOADER - Crash collector address was not set.");
        __NRMACrashDataUploaderInProgressRequestCount--;
        return;
    }
    if (path == nil) {
        NRLOG_AGENT_ERROR(@"NEWRELIC CRASH UPLOADER - CrashData path was not set.");
        __NRMACrashDataUploaderInProgressRequestCount--;
        return;
    }

    // Cross-launch guard: stop retrying a report that has already failed many launches.
    if (![self shouldUploadFileWithUniqueIdentifier:path.absoluteString]) {
        NRLOG_AGENT_VERBOSE(@"NEWRELIC CRASH UPLOADER - Cross-launch retry limit reached, removing: %@", path.absoluteString);
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityPrefix@"/Crash/RemoveStale"
                                                        value:@1
                                                        scope:nil]];
        [_fileManager removeItemAtURL:path error:nil];
        __NRMACrashDataUploaderInProgressRequestCount--;
        return;
    }

    NSData* reqData = [NSData dataWithContentsOfURL:path options:0 error:nil];
    if (reqData.length > kNRMAMaxPayloadSizeLimit) {
        NRLOG_AGENT_ERROR(@"Unable to upload crash log because payload is larger than 1 MB, discarding");
        [NRMASupportMetricHelper enqueueMaxPayloadSizeLimitMetric:@"mobile_crash"];
        [self removeCrashLogAtpath:path];
        __NRMACrashDataUploaderInProgressRequestCount--;
        return;
    }

    NSURLRequest* request = [self buildPost];
    NRLOG_AGENT_VERBOSE(@"NEWRELIC CRASH UPLOADER - Perform crash upload");

    __weak __typeof__(self) weakSelf = self;

    // NRMARetryingHTTPClient handles all in-session retry with exponential backoff.
    // The completion fires exactly once with the terminal outcome.
    [self.httpClient uploadRequest:request
                           fileURL:path
                          endpoint:@"mobile_crash"
                        completion:^(NSData* responseData, NSHTTPURLResponse* response, NSError* error) {
        __NRMACrashDataUploaderInProgressRequestCount--;

        NRLOG_AGENT_VERBOSE(@"NEWRELIC CRASH UPLOADER - Crash Upload Response: %@", response);
        if (error) {
            NRLOG_AGENT_ERROR(@"NEWRELIC CRASH UPLOADER - Upload Error: %@", error);
        }

        NSInteger statusCode = response.statusCode;
        BOOL success = !error && (statusCode == 200 || statusCode == 500);

        if (success) {
            [NRMASupportMetricHelper enqueueDataUseMetric:@"mobile_crash"
                                                     size:(long)reqData.length
                                                 received:response.expectedContentLength];
            [weakSelf removeCrashLogAtpath:path];
            return;
        }

        // Permanent 4xx rejection — discard the file so we don't retry across launches.
        if (statusCode == 400 || statusCode == 403) {
            NRLOG_AGENT_ERROR(@"NEWRELIC CRASH UPLOADER - crash log permanently rejected (HTTP %ld), discarding", (long)statusCode);
            [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRMACrashOfflineRejectedMetric
                                                            value:@1
                                                            scope:nil]];
            [weakSelf removeCrashLogAtpath:path];
            return;
        }

        // All other failures: leave the file on disk for the next-launch retry.
        NRLOG_AGENT_VERBOSE(@"NEWRELIC CRASH UPLOADER - failed to upload crash log, keeping for next launch: %@", path.path);
    }];
}

- (void) removeCrashLogAtpath:(NSURL*)path {
    [self stopTrackingFileUploadWithUniqueIdentifier:path.absoluteString];
    NSError* error = nil;
    if (![_fileManager removeItemAtURL:path error:&error]) {
        NRLOG_AGENT_ERROR(@"NEWRELIC CRASH UPLOADER - Failed to remove crash file: %@, %@", path.path, error.description);
    }
}

- (NSURLRequest*) buildPost {
    return [super newPostWithURI:[NSString stringWithFormat:@"%@%@/%@",
                                  _useSSL ? @"https://" : @"http://",
                                  _crashCollectorHost,
                                  kNRMA_CR_CrashCollectorPath]];
}

- (void) stopTrackingFileUploadWithUniqueIdentifier:(NSString*)key {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:key];
    [defaults synchronize];
}

- (BOOL) shouldUploadFileWithUniqueIdentifier:(NSString*)key {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSNumber* value = [defaults objectForKey:key];
    value = value ? @(value.integerValue + 1) : @1;
    if (value.integerValue > kNRMAMaxCrashUploadRetry) {
        [self stopTrackingFileUploadWithUniqueIdentifier:key];
        return NO;
    }
    [defaults setObject:value forKey:key];
    [defaults synchronize];
    return YES;
}

@end
