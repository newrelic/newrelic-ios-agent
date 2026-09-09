//
//  NRMATraceConfigurations.h
//  NewRelicAgent
//
//  Created by Jared Stanbrough on 10/10/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Activity traces retained per in-flight harvest when the collector does not say otherwise.
///
/// Must never be 0: the collection gate is `count < maxTotalTraceCount`
/// (`+[NRMAHarvestController shouldCollectTraces]`), so a cap of 0 is false for every trace and
/// silently drops all activity traces for the whole session.
#define NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT 1000

/// Whether a value parsed out of a collector response (or out of the NSUserDefaults round trip) can
/// safely be sent -intValue/-doubleValue.
///
/// Numeric collector fields arrive as JSON numbers and are persisted as NSNumber, but JSON `null`
/// decodes to NSNull and a reshaped field can be an array or a dictionary. None of those respond to
/// the numeric accessors, so converting one without checking is an unrecognized-selector crash
/// rather than a fallback to the default.
static inline BOOL NRMAIsNumberLikeConfigurationValue(id value) {
    return [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]];
}

@interface NRMATraceConfigurations : NSObject
@property(nonatomic,assign) int maxTotalTraceCount;
@property (atomic, strong) NSMutableArray *activityTraceConfigurations;

/// Parses the collector's `at_capture` value: a 2-element array of
/// `[maxTotalTraceCount, [[namePattern, totalTraceCount], ...]]`.
///
/// `maxTotalTraceCount` defaults to NRMA_DEFAULT_MAX_TOTAL_TRACE_COUNT when `array` is nil or is not
/// in that shape, so a missing or reshaped `at_capture` degrades to the default cap rather than to 0.
- (id) initWithArray:(NSArray*)array;
+ (id) defaultTraceConfigurations;

/// Inverse of -initWithArray:, for persisting to NSUserDefaults. Emits plain arrays (not
/// NRMATraceConfiguration objects) so the value is plist-serializable and round-trips back through
/// -initWithArray:.
- (NSArray*) asArray;

@end
