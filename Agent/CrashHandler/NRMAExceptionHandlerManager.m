//
//  NRMAExceptionHandlerManager.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/17/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NRMAExceptionMetaDataStore.h"

#import "NRMAExceptionHandlerManager.h"
#import "NRMAUncaughtExceptionHandler.h"
#import "NRMACrashReportFileManager.h"
#if TARGET_OS_WATCH
#else
#import "PLCrashNamespace.h"
#import "PLCrashReporter.h"
#endif
#import "NRMACrashDataUploader.h"
#import "NRLogger.h"
#import "NRConstants.h"
#import "NRMAMemoryVitals.h"
#import "NewRelicInternalUtils.h"
#import "NRMATaskQueue.h"
#import "NRMAMetric.h"
#import "NRMACrashReporterRecorder.h"
#import "Constants.h"

@interface NRMAExceptionHandlerManager  ()
#if !TARGET_OS_WATCH
@property(strong) PLCrashReporter* crashReporter;
#endif
@property(strong) NRMACrashReportFileManager* reportManager;
@property(strong) NRMAUncaughtExceptionHandler* handler;
@end

@implementation NRMAExceptionHandlerManager
static NRMAExceptionHandlerManager* __manager;
static const NSString* NRMAManagerAccessorLock = @"managerLock";
+ (void) setManager:(NRMAExceptionHandlerManager*)manager
{
    @synchronized(NRMAManagerAccessorLock) {
        if (__manager) {
            [NRMAHarvestController removeHarvestListener:__manager];
        }
        __manager = manager;
        if (manager != nil) {
            [NRMAHarvestController addHarvestListener:__manager];
        }
    }

}

+ (NRMAExceptionHandlerManager*) manager
{
    @synchronized(NRMAManagerAccessorLock) {
        return __manager;
    }
}


+ (void) startHandlerWithLastSessionsAttributes:(NSDictionary*)attributes
                             andAnalyticsEvents:(NSArray*)events
                                  uploadManager:(NRMACrashDataUploader*)uploader {
    NRMA_updateDiskUsage();
    NRMA_updateModelNumber();
    [self setManager:[[NRMAExceptionHandlerManager alloc] initWithLastSessionsAttributes:attributes
                                                                      andAnalyticsEvents:events
                                                                           uploadManager:uploader]];
    //The following line triggers a memory usage notification.
    [NRMAMemoryVitals memoryUseInMegabytes];
    [[self manager] updateNetworkingStatus];
    [[self manager].handler start];
    [[self manager] fireDelayedProcessing];
}

- (instancetype) initWithLastSessionsAttributes:(NSDictionary*)attributes
                             andAnalyticsEvents:(NSArray*)events
                                  uploadManager:(NRMACrashDataUploader*)uploader {
    self = [super init];
    if (self) {
        self.uploader = uploader;
        [self registerObservers];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryUsageNotification:) name:kNRMemoryUsageDidChangeNotification object:nil];

        // PLCrashReporterSignalHandlerTypeBSD tried and true vs MACH handler...
        // it's recommended to use BSD in production, while MACH can be used in dev if you really want to.
        // first iteration will default to BSD, with no option to change this.
#if !TARGET_OS_WATCH
        PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeBSD;

        // We don't want to attempt to symbolicate at runtime due to the possibility of stack corruption
        // as well as it being inaccurate. Let's save it for the server where we have the dsym files!
        PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:signalHandlerType
                                                                           symbolicationStrategy:PLCrashReporterSymbolicationStrategyNone];
        _crashReporter = [[PLCrashReporter alloc] initWithConfiguration:config];

        PLCrashReporterCallbacks callback;
        callback.handleSignal = NRMA_writeNRMeta;
        callback.version = 0;


        PLCrashReporterCallbacks* callbacks  = &callback;
        [_crashReporter setCrashCallbacks:callbacks];
        _reportManager = [[NRMACrashReportFileManager alloc] initWithCrashReporter:_crashReporter];

        if ([_crashReporter hasPendingCrashReport]) {
            // Here we process pending crash reports.
            // This would possibly mean the last session ended in a crash.

            // Check if there are session replay frames for this crashed session
            // If so, retroactively add the hasReplay attribute
            NSMutableDictionary *modifiedAttributes = attributes ? [attributes mutableCopy] : [NSMutableDictionary new];
            if ([self hasSessionReplayFrames]) {
                NRLOG_AGENT_DEBUG(@"Found session replay frames for crashed session - adding hasReplay attribute");
                modifiedAttributes[kNRMA_RA_hasReplay] = @YES;
            }

            [_reportManager processReportsWithSessionAttributes:modifiedAttributes
                                                analyticsEvents:events];

            NRMAReachability* r = [NewRelicInternalUtils reachability];
            @synchronized(r) {
                NRMANetworkStatus status = [r currentReachabilityStatus];
                if (status != NotReachable) { // Because we support offline mode check if we're online before sending the crash reports
                    [self.uploader uploadCrashReports];
                }
            }
        }
        else {
            if ([self previousSessionWasInSessionReplayErrorMode]) {
                // No crash occurred and the previous session was recording session replay in
                // error mode, where frames are only buffered to disk and uploaded when an
                // error/crash happens. With no crash, those buffered frames are now stale and
                // can be cleared.
                [self clearSessionReplayFrames];
            }
        }
        self.handler = [[NRMAUncaughtExceptionHandler alloc] initWithCrashReporter:_crashReporter];
#endif
    }
    return self;
}

- (void) registerObservers
{
    // TODO: Add support for NSExtensionHostDidBecomeActiveNotification
#if !TARGET_OS_WATCH
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fireDelayedProcessing)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#endif
}


- (void) fireDelayedProcessing
{
    // This prevents multiple execution of executeDelayedProcessing on instances where
    // both the network becomes available and the application did become active.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(executeDelayedProcessing) object:nil];
    [self performSelector:@selector(executeDelayedProcessing) withObject:nil afterDelay:.5];
}

- (void) executeDelayedProcessing
{
    if (![self.handler isActive]) {
        return;
    }
    if (![self.handler isExceptionHandlerValid]) {

        // here the crash file manager gathers and transmits to the crash harvester.

        NSArray*(^myblock)(void) = ^NSArray*(void){
            NSMutableArray* list = [[NSMutableArray alloc] init];
            NRMACrashReporterRecorder* crashRecorder = [[NRMACrashReporterRecorder alloc] init];
            if ([crashRecorder isCrashlyticsDefined]) {
                [list addObject:@"Crashlytics"];
            }
            if ([crashRecorder isHockeyDefined]) {
                [list addObject:@"HockeyApp"];
            }
            if ([crashRecorder isCrittercismDefined]) {
                [list addObject:@"Crittercism"];
            }
            if ([crashRecorder isTestFlightDefined]) {
                [list addObject:@"TestFlight"];
            }
            if ([crashRecorder isFlurryDefined]) {
                [list addObject:@"Flurry"];
            }
            return list;
        };

        NSArray* crashFrameworkList = myblock();
        NSString* errorMessage = @"Error: The New Relic exception handler has been replaced. This may result in crashes no longer reporting to New Relic.";
        if ([crashFrameworkList count]) {
            errorMessage = [errorMessage stringByAppendingString:[NSString stringWithFormat:@"\n\tWe've detected the following framework(s) that may be responsible for replacing the uncaught exception handler:\n\t\t%@",[crashFrameworkList componentsJoinedByString:@"\n\t\t"]]];
        }
        NRLOG_AGENT_ERROR(@"%@",errorMessage);
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRMAExceptionHandlerHijackedMetric 
                                                        value:@1
                                                        scope:nil]];
    }

}

- (void) onHarvestBefore
{
    NRMA_updateDiskUsage();
    //The following line triggers a memory usage notification.
    [NRMAMemoryVitals memoryUseInMegabytes];

    [self updateNetworkingStatus];
}

- (void) updateNetworkingStatus
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,
                                             0),
                   ^{
                       switch([NewRelicInternalUtils networkStatus]){
                           case NotReachable:
                               NRMA_setNetworkConnectivity("Not Reachable");
                               break;
                           case  ReachableViaWiFi:
                               NRMA_setNetworkConnectivity("WiFi");
                               break;
                           case ReachableViaWWAN:
                               NRMA_setNetworkConnectivity("Cell");
                               break;
                           default:
                               NRMA_setNetworkConnectivity("Unknown");
                               break;
                       }
                   });
}

static const NSString* __memoryUsageLock = @"Lock";
- (void) didReceiveMemoryUsageNotification:(NSNotification*)memoryUsageNotification
{
    NSString* memoryUsageMB = (NSString*)memoryUsageNotification.object;

    if ([memoryUsageMB isKindOfClass:[NSString class]] && memoryUsageMB.length) {
        //NSNotifications are not thread safe so we need to synchronize before we start setting things.
        @synchronized(__memoryUsageLock) {
            NRMA_setMemoryUsage(memoryUsageMB.UTF8String);
        }
    }
}

// Determines whether the previous session left a stale error-mode session replay buffer.
// While recording in error mode, session replay drops a marker file into the frames folder
// (see NRMASessionReplay.processFrameToFile) and removes it when it leaves error mode. So the
// marker's presence here means the previous session ended while still in error mode.
- (BOOL) previousSessionWasInSessionReplayErrorMode
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *markerPath = [[documentsDirectory stringByAppendingPathComponent:kNRMA_SessionReplayFrames_folder]
                            stringByAppendingPathComponent:kNRMA_SessionReplayErrorMode_marker];

    return [[NSFileManager defaultManager] fileExistsAtPath:markerPath];
}

- (BOOL) hasSessionReplayFrames
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *framesDirectory = [documentsDirectory stringByAppendingPathComponent:kNRMA_SessionReplayFrames_folder];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;

    // Check if SessionReplayFrames directory exists
    if (![fileManager fileExistsAtPath:framesDirectory isDirectory:&isDirectory] || !isDirectory) {
        return NO;
    }

    // Check if there are any session directories with frames
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:framesDirectory error:&error];
    if (error) {
        NRLOG_AGENT_DEBUG(@"Error reading SessionReplayFrames directory: %@", error.localizedDescription);
        return NO;
    }

    // Look for session directories (UUIDs) or upload URL files
    for (NSString *item in contents) {
        NSString *itemPath = [framesDirectory stringByAppendingPathComponent:item];
        BOOL itemIsDirectory = NO;
        [fileManager fileExistsAtPath:itemPath isDirectory:&itemIsDirectory];

        // Check for session directories or upload URL files
        if (itemIsDirectory) {
            // Check if this session directory has any frame files
            NSArray *sessionContents = [fileManager contentsOfDirectoryAtPath:itemPath error:nil];
            for (NSString *file in sessionContents) {
                if ([file hasPrefix:@"frame_"] && [file hasSuffix:@".json"]) {
                    return YES;
                }
            }
        } else if ([item hasSuffix:@"_upload_url.txt"]) {
            // Found an upload URL file, indicating there was session replay data
            return YES;
        }
    }

    return NO;
}

- (void) clearSessionReplayFrames
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *framesDirectory = [documentsDirectory stringByAppendingPathComponent:kNRMA_SessionReplayFrames_folder];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:framesDirectory]) {
        NSError *error;
        if ([fileManager removeItemAtPath:framesDirectory error:&error]) {
            NRLOG_AGENT_DEBUG(@"Cleared SessionReplayFrames directory");
        } else {
            NRLOG_AGENT_DEBUG(@"Failed to clear SessionReplayFrames directory: %@", error.localizedDescription);
        }
    }
}

@end
