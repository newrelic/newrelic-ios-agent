//
//  NRMATraceConfigurations.m
//  NewRelicAgent
//
//  Created by Jared Stanbrough on 10/10/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATraceConfigurations.h"
#import "NRMATraceConfiguration.h"
#import "NRLogger.h"

@implementation NRMATraceConfigurations

- (id) initWithArray:(NSArray*)array
{
    self = [super init];
    if (self) {
        // Seed the default *before* parsing. Leaving this at 0 when at_capture is absent or
        // reshaped makes the collection gate (count < maxTotalTraceCount) false for every trace,
        // which drops all activity traces for the entire session and logs "Maximum number of
        // Activity Traces collected. Skipping" for each one.
        self.maxTotalTraceCount = NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT;

        // Everything below has to tolerate an arbitrary decoded JSON graph. at_capture is typed
        // NSArray* here, but the collector can send null (NSNull) or any other shape, and every
        // conversion in this method (-count, -objectAtIndex:, -intValue) is an unrecognized selector
        // on the wrong type.
        if (![array isKindOfClass:[NSArray class]]) {
            if (array != nil) {
                NRLOG_AGENT_WARNING(@"Unexpected at_capture type (%@, expected an array); using default max activity trace count of %d.",
                                    NSStringFromClass([array class]), NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT);
            }
            return self;
        }

        if (array.count != 2) {
            NRLOG_AGENT_WARNING(@"Unexpected at_capture shape (%lu elements, expected 2); using default max activity trace count of %d.",
                                (unsigned long)array.count, NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT);
            return self;
        }

        id maxTotalTraceCount = [array objectAtIndex:0];
        if (!NRMAIsNumberLikeConfigurationValue(maxTotalTraceCount)) {
            NRLOG_AGENT_WARNING(@"Unexpected at_capture max activity trace count type (%@, expected a number); using default of %d.",
                                NSStringFromClass([maxTotalTraceCount class]), NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT);
            return self;
        }

        self.maxTotalTraceCount = [maxTotalTraceCount intValue];
        if (self.maxTotalTraceCount <= 0) {
            NRLOG_AGENT_WARNING(@"at_capture specified a max activity trace count of %d, which would drop every activity trace; using %d.",
                                self.maxTotalTraceCount, NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT);
            self.maxTotalTraceCount = NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT;
        }

        NSArray *configurations = [array objectAtIndex:1];
        if (![configurations isKindOfClass:[NSArray class]]) {
            return self;
        }

        self.activityTraceConfigurations = [[NSMutableArray alloc] initWithCapacity:configurations.count];

        for (int configurationIndex = 0; configurationIndex < configurations.count; configurationIndex++) {
            id configArray = [configurations objectAtIndex:configurationIndex];
            // Each entry must be a [namePattern, totalTraceCount] pair. Anything else is skipped
            // rather than sent to -objectAtIndex:, which would raise on a non-array element.
            if (![configArray isKindOfClass:[NSArray class]] || [configArray count] < 2) {
                NRLOG_AGENT_WARNING(@"Skipping malformed at_capture trace configuration at index %d.", configurationIndex);
                continue;
            }

            // The pair's own element types are just as unchecked as the outer array's: the pattern
            // has to be a string because -activityTraceNamePattern is one and is later matched
            // against trace names, and the count has to be convertible to an int.
            id namePattern = [configArray objectAtIndex:0];
            id totalTraceCount = [configArray objectAtIndex:1];
            if (![namePattern isKindOfClass:[NSString class]] || !NRMAIsNumberLikeConfigurationValue(totalTraceCount)) {
                NRLOG_AGENT_WARNING(@"Skipping at_capture trace configuration at index %d with unexpected element types (%@, %@).",
                                    configurationIndex, NSStringFromClass([namePattern class]), NSStringFromClass([totalTraceCount class]));
                continue;
            }

            NRMATraceConfiguration *configuration = [[NRMATraceConfiguration alloc] init];

            // Set the name and total count.
            configuration.activityTraceNamePattern = namePattern;
            configuration.totalTraceCount = [totalTraceCount intValue];

            [self.activityTraceConfigurations addObject:configuration];
        }
    }
    return self;
}

- (NSArray*) asArray
{
    NSMutableArray* configurations = [[NSMutableArray alloc] init];
    for (NRMATraceConfiguration* configuration in self.activityTraceConfigurations) {
        [configurations addObject:@[configuration.activityTraceNamePattern ?: @"",
                                    @(configuration.totalTraceCount)]];
    }
    return @[@(self.maxTotalTraceCount), configurations];
}

+ (id) defaultTraceConfigurations
{
    NRMATraceConfigurations* traceConfigurations = [[NRMATraceConfigurations alloc] init];
    traceConfigurations.maxTotalTraceCount = NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT;
    return traceConfigurations;
}
@end
