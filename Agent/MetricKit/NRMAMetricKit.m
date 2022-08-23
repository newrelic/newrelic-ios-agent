//
//  NRMAMetricKit.m
//  Agent
//
//  Created by Chris Dillard on 8/16/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import "NRMAMetricKit.h"
#import "NRMAAgentConfiguration.h"
#import "NRLogger.h"
#import "NewRelic/NewRelic.h"

static NRMAMetricKit *_sharedInstance;

@implementation NRMAMetricKit

+ (NRMAMetricKit *)sharedInstance
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _sharedInstance = [[NRMAMetricKit alloc] init];
    });

    return _sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) { }
    return self;
}

- (void)start {
    // MetricKit only works with iOS 13+.
    if (@available(iOS 13.0, *)) {
        [[MXMetricManager sharedManager] addSubscriber:self];

        id payloads = [MXMetricManager sharedManager].pastPayloads;
        [self didReceiveMetricPayloads:payloads];

        id diagnosticPayloads = [NSMutableArray new];

        if (@available(iOS 14.0, *)) {
            diagnosticPayloads = [MXMetricManager sharedManager].pastDiagnosticPayloads;
            [self didReceiveDiagnosticPayloads:diagnosticPayloads];
        } else {
            // Fallback on earlier versions
        }

        NRLOG_INFO(@"NRMAMetricKit started: did rcv pastPayloads: %lu count, and pastDiagnosticPayloads: %lu count", (unsigned long)[payloads count], (unsigned long)[diagnosticPayloads count]);

    } else {
        // MetricKit is not available on devices before iOS 13.
        NRLOG_INFO(@"NRMAMetricKit NOT Started on pre iOS 13 devices.");
    }
}

- (BOOL)beginRecordingExtendedLaunchTask:(NSString* _Nonnull)taskIdentifier API_AVAILABLE(ios(16.0)) {
    NSError *error = nil;
    return [MXMetricManager extendLaunchMeasurementForTaskID:taskIdentifier error:&error];
}

- (BOOL)endRecordingExtendedLaunchTask:(NSString* _Nonnull)taskIdentifier API_AVAILABLE(ios(16.0)) {
    NSError *error = nil;
    return [MXMetricManager finishExtendedLaunchMeasurementForTaskID:taskIdentifier error:&error];
}

- (double)averageForBuckets:(NSArray<MXHistogramBucket *> * _Nonnull)buckets  API_AVAILABLE(ios(13.0)){
    if (buckets.count == 0){ return 0; }

    int numBuckets = 0;
    double totalDurations = 0;

    for (MXHistogramBucket *bucket in buckets) {
        numBuckets += bucket.bucketCount;
        totalDurations += (double)bucket.bucketCount * bucket.bucketEnd.doubleValue;
    }
    return totalDurations / (double)numBuckets;
}

// MXMetricManagerSubscriber

- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> * _Nonnull)payloads  API_AVAILABLE(ios(13.0)){

    if ([payloads count] == 0) { return; }

    // Filter captured payloads to latest app version only in case it was updated.
    NSString* appVersion = [NRMAAgentConfiguration connectionInformation].applicationInformation.appVersion;
    NSArray *filteredPayloads = [payloads filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MXMetricPayload *payload, NSDictionary *bindings) {
        if (payload.includesMultipleApplicationVersions) {
            return NO;
        }

        return [payload.latestApplicationVersion isEqualToString:appVersion];
    }]];

    for (MXMetricPayload *payload in filteredPayloads) {

        if (@available(iOS 16.0, *)) {
            NSArray<MXHistogramBucket*> * extendedLaunchBuckets =
                [payload.applicationLaunchMetrics.histogrammedExtendedLaunch.bucketEnumerator allObjects];
            double averageExtendedLaunchTime = [self averageForBuckets:extendedLaunchBuckets];

            if (averageExtendedLaunchTime > 0) {
                NRLOG_INFO(@"~~ AVERAGE EXTENDED LAUNCH TIME: %fms",averageExtendedLaunchTime);

                [NewRelic recordMetricWithName:@"AppLaunchExtended" category:@"AppLaunch" value:[NSNumber numberWithDouble:averageExtendedLaunchTime / 1000] valueUnits:kNRMetricUnitSeconds];
            }
        }

        // Cold app launch: time between app icon tapped and first draw.
        NSArray<MXHistogramBucket*> * coldLaunchBuckets =
            [payload.applicationLaunchMetrics.histogrammedTimeToFirstDraw.bucketEnumerator allObjects];
        double averageColdLaunchTime = [self averageForBuckets:coldLaunchBuckets];
        NRLOG_INFO(@"~~ AVERAGE COLD LAUNCH TIME: %fms",averageColdLaunchTime);

        [NewRelic recordMetricWithName:@"AppLaunchCold" category:@"AppLaunch" value:[NSNumber numberWithDouble:averageColdLaunchTime / 1000] valueUnits:kNRMetricUnitSeconds];

        if (@available(iOS 15.2, *)) {
            // WARM app launch time
            NSArray<MXHistogramBucket*> *warmLaunchBuckets =
                [payload.applicationLaunchMetrics.histogrammedOptimizedTimeToFirstDraw.bucketEnumerator allObjects];
            double averageWarmLaunchTime = [self averageForBuckets:warmLaunchBuckets];

            if (averageWarmLaunchTime > 0) {
                NRLOG_INFO(@"~~ AVERAGE WARM LAUNCH TIME: %fms",averageWarmLaunchTime);

                [NewRelic recordMetricWithName:@"AppLaunchWarm" category:@"AppLaunch" value:[NSNumber numberWithDouble:averageWarmLaunchTime / 1000] valueUnits:kNRMetricUnitSeconds];
            }

        } else {
            // Fallback on earlier versions
            NRLOG_INFO(@"NRMAMetricKit: Warm Launch Metric available in iOS 15.2+.");
        }

        // App start up from backgrounded app state.
        NSArray<MXHistogramBucket*> *appResumeBuckets =
            [payload.applicationLaunchMetrics.histogrammedApplicationResumeTime.bucketEnumerator allObjects];
        double averageResumeTime = [self averageForBuckets:appResumeBuckets];

        if (averageResumeTime > 0) {
            NRLOG_INFO(@"~~ AVERAGE RESUME TIME: %fms",averageResumeTime);

            [NewRelic recordMetricWithName:@"AppResume" category:@"AppLaunch" value:[NSNumber numberWithDouble:averageResumeTime / 1000] valueUnits:kNRMetricUnitSeconds];
        }
    }
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> * _Nonnull)payloads  API_AVAILABLE(ios(14.0)){

    if ([payloads count] == 0) { return; }

    for (MXDiagnosticPayload *payload in payloads) {
        NRLOG_INFO(@"~~ RCV DIAG PAYLOAD: %@",payload);

        if (@available(iOS 16.0, *)) {
            double totalDurations = 0;

            for (MXAppLaunchDiagnostic *diagnostic in [payload appLaunchDiagnostics]) {
                totalDurations += diagnostic.launchDuration.doubleValue;
            }
            double averageLaunchTime = totalDurations / [[payload appLaunchDiagnostics] count];
            
            if (averageLaunchTime > 0) {
                NRLOG_INFO(@"~~ AVERAGE LAUNCH TIME (includes extended launch tasks): %fms",averageLaunchTime);

                [NewRelic recordMetricWithName:@"AppLaunchDiagnostic" category:@"AppLaunch" value:[NSNumber numberWithDouble:averageLaunchTime / 1000] valueUnits:kNRMetricUnitSeconds];
            }

        } else {
            // Fallback on earlier versions
        }
    }
}

@end
