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
#import "PLCrashNamespace.h"
#import "PLCrashReporter.h"
#import "NRMACrashDataUploader.h"
#import "NRLogger.h"
#import "NRConstants.h"
#import "NRMAMemoryVitals.h"
#import "NewRelicInternalUtils.h"
#import "NRMATaskQueue.h"
#import "NRMAMetric.h"
#import "NRMACrashReporterRecorder.h"

@interface NRMAExceptionHandlerManager  ()
@property(strong) PLCrashReporter* crashReporter;
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
            [_reportManager processReportsWithSessionAttributes:attributes
                                                analyticsEvents:events];

            NRMAReachability* r = [NewRelicInternalUtils reachability];
            @synchronized(r) {
                NRMANetworkStatus status = [r currentReachabilityStatus];
                if (status != NotReachable) { // Because we support offline mode check if we're online before sending the crash reports
                    [self.uploader uploadCrashReports];
                }
            }
        }

        self.handler = [[NRMAUncaughtExceptionHandler alloc] initWithCrashReporter:_crashReporter];
    }
    return self;
}

- (void) registerObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fireDelayedProcessing)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
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
        NRLOG_ERROR(@"%@",errorMessage);
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

@end
