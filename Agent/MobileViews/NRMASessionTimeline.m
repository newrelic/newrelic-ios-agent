//
//  NRMASessionTimeline.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMASessionTimeline.h"
#import "NRLogger.h"

const NSUInteger NRMASessionTimelineMaxRows = 4000;

static NSString * const kNRAttr_viewName       = @"viewName";
static NSString * const kNRAttr_viewInstanceId = @"viewInstanceId";
static NSString * const kNRAttr_appeared       = @"appeared";
static NSString * const kNRAttr_reappeared     = @"reappeared";
static NSString * const kNRAttr_timeVisible    = @"timeVisible";
static NSString * const kNRAttr_loadTime       = @"loadTime";
static NSString * const kNRAttr_timingName     = @"timingName";
static NSString * const kNRAttr_timingValue    = @"timingValue";

typedef NS_ENUM(NSInteger, NRMATimelineAppeared) {
    NRMATimelineAppearedAbsent = -1,   // the current contract: one event per visit, no `appeared`
    NRMATimelineAppearedNo     = 0,
    NRMATimelineAppearedYes    = 1,
};

/// One recorded row, reduced to the fields build_timeline() reads.
@interface NRMATimelineRow : NSObject
@property (nonatomic) BOOL isTiming;
@property (nonatomic) double timestamp;
@property (nonatomic, copy, nullable) NSString *instance;
@property (nonatomic, copy, nullable) NSString *name;       // viewName, or timingName
@property (nonatomic) NRMATimelineAppeared appeared;
@property (nonatomic) double timeVisible;                   // NaN when absent
@property (nonatomic) double loadTime;                      // NaN when absent
@property (nonatomic) BOOL reappeared;
@property (nonatomic, strong, nullable) NSNumber *value;    // timingValue
@end

@implementation NRMATimelineRow
@end

@implementation NRMASessionTimelineVisit

- (instancetype)init {
    if ((self = [super init])) {
        _marks = [NSMutableArray array];
        _end = NAN;
        _loadMilliseconds = NAN;
    }
    return self;
}

@end

static NSString *NRMATimelineString(id value) {
    return ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) ? value : nil;
}

static double NRMATimelineNumber(id value) {
    return [value isKindOfClass:[NSNumber class]] ? [(NSNumber *)value doubleValue] : NAN;
}

@implementation NRMASessionTimeline {
    NSMutableArray<NRMATimelineRow *> *_rows;
    double _exactOrigin;     // min(timestamp - timeSinceLoad), NaN until seen
    double _earliestStamp;   // min(timestamp), NaN until seen
    BOOL _truncated;
}

- (instancetype)init {
    if ((self = [super init])) {
        _rows = [NSMutableArray array];
        _exactOrigin = NAN;
        _earliestStamp = NAN;
    }
    return self;
}

// Rows are never mutated once stored, so sharing them between copies is safe.
- (id)copyWithZone:(NSZone *)zone {
    NRMASessionTimeline *copy = [[[self class] allocWithZone:zone] init];
    copy->_rows = [_rows mutableCopy];
    copy->_exactOrigin = _exactOrigin;
    copy->_earliestStamp = _earliestStamp;
    copy->_truncated = _truncated;
    return copy;
}

#pragma mark - Ingest

- (void)noteEventAtTimestamp:(double)timestamp sessionElapsedSeconds:(double)sessionElapsedSeconds {
    if (isnan(timestamp)) return;
    if (isnan(_earliestStamp) || timestamp < _earliestStamp) _earliestStamp = timestamp;
    if (!isnan(sessionElapsedSeconds)) {
        double origin = timestamp - sessionElapsedSeconds * 1000.0;
        if (isnan(_exactOrigin) || origin < _exactOrigin) _exactOrigin = origin;
    }
}

- (BOOL)admitRow {
    if (_rows.count < NRMASessionTimelineMaxRows) return YES;
    if (!_truncated) {
        _truncated = YES;
        NRLOG_AGENT_VERBOSE(@"[SessionFlow] timeline truncated at %lu rows; later visits are not drawn.",
                            (unsigned long)NRMASessionTimelineMaxRows);
    }
    return NO;
}

- (void)recordMobileViewAttributes:(NSDictionary<NSString *, id> *)attributes
                         timestamp:(double)timestamp
             sessionElapsedSeconds:(double)sessionElapsedSeconds {
    [self noteEventAtTimestamp:timestamp sessionElapsedSeconds:sessionElapsedSeconds];
    if (attributes.count == 0 || isnan(timestamp) || ![self admitRow]) return;

    NRMATimelineRow *row = [[NRMATimelineRow alloc] init];
    row.timestamp = timestamp;
    row.instance = NRMATimelineString(attributes[kNRAttr_viewInstanceId]);
    row.name = NRMATimelineString(attributes[kNRAttr_viewName]);
    id appeared = attributes[kNRAttr_appeared];
    row.appeared = [appeared isKindOfClass:[NSNumber class]]
        ? ([appeared boolValue] ? NRMATimelineAppearedYes : NRMATimelineAppearedNo)
        : NRMATimelineAppearedAbsent;
    row.timeVisible = NRMATimelineNumber(attributes[kNRAttr_timeVisible]);
    row.loadTime = NRMATimelineNumber(attributes[kNRAttr_loadTime]);
    row.reappeared = [attributes[kNRAttr_reappeared] isKindOfClass:[NSNumber class]]
        && [attributes[kNRAttr_reappeared] boolValue];
    [_rows addObject:row];
}

- (void)recordViewTimingAttributes:(NSDictionary<NSString *, id> *)attributes
                         timestamp:(double)timestamp
             sessionElapsedSeconds:(double)sessionElapsedSeconds {
    [self noteEventAtTimestamp:timestamp sessionElapsedSeconds:sessionElapsedSeconds];
    if (attributes.count == 0 || isnan(timestamp) || ![self admitRow]) return;

    NRMATimelineRow *row = [[NRMATimelineRow alloc] init];
    row.isTiming = YES;
    row.timestamp = timestamp;
    row.instance = NRMATimelineString(attributes[kNRAttr_viewInstanceId]);
    row.name = NRMATimelineString(attributes[kNRAttr_timingName]);
    id value = attributes[kNRAttr_timingValue];
    row.value = [value isKindOfClass:[NSNumber class]] ? value : nil;
    [_rows addObject:row];
}

#pragma mark - Read

- (double)originIsExact:(BOOL *)exact {
    BOOL isExact = !isnan(_exactOrigin);
    if (exact) *exact = isExact;
    return isExact ? _exactOrigin : _earliestStamp;
}

- (NSArray<NRMASessionTimelineVisit *> *)visitsWithMaximum:(NSUInteger)maximumVisits
                                                   dropped:(NSUInteger *)dropped {
    // The script sorts the dump by timestamp before walking it. Stable, so rows that share a
    // timestamp keep the order they were recorded in.
    NSArray<NRMATimelineRow *> *rows =
        [_rows sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(NRMATimelineRow *a, NRMATimelineRow *b) {
            if (a.timestamp < b.timestamp) return NSOrderedAscending;
            if (a.timestamp > b.timestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];

    // Insertion-ordered, as a Python dict is: a later row for the same instance replaces the visit
    // but keeps the position of the first.
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    NSMutableDictionary<NSString *, NRMASessionTimelineVisit *> *visits = [NSMutableDictionary dictionary];
    NSMutableArray<NSArray *> *marks = [NSMutableArray array];   // @[instance, @[ts, name, value]]

    void (^store)(NSString *, NRMASessionTimelineVisit *) = ^(NSString *instance, NRMASessionTimelineVisit *visit) {
        if (visits[instance] == nil) [order addObject:instance];
        visits[instance] = visit;
    };

    for (NRMATimelineRow *row in rows) {
        if (row.isTiming) {
            // Attached after the walk: a timing is recorded during its visit, so under the
            // one-event-per-visit contract it arrives *before* the event that names the visit.
            if (row.instance == nil || row.name == nil || row.value == nil) continue;
            [marks addObject:@[row.instance, @[@(row.timestamp), row.name, row.value]]];
            continue;
        }
        if (row.appeared == NRMATimelineAppearedAbsent && row.name != nil && row.instance != nil
                && !isnan(row.timeVisible)) {
            // One event per visit, emitted when it ends: the timestamp is the bar's right edge and
            // timeVisible reaches back to its left.
            NRMASessionTimelineVisit *visit = [[NRMASessionTimelineVisit alloc] init];
            visit.name = row.name;
            visit.appear = row.timestamp - row.timeVisible;
            visit.loadMilliseconds = row.loadTime;
            visit.reappeared = row.reappeared;
            visit.end = row.timestamp;
            store(row.instance, visit);
        } else if (row.appeared != NRMATimelineAppearedNo && row.name != nil) {
            // The older contract's appear event: the bar starts here and a disappear ends it.
            if (row.instance == nil) continue;
            NRMASessionTimelineVisit *visit = [[NRMASessionTimelineVisit alloc] init];
            visit.name = row.name;
            visit.appear = row.timestamp;
            visit.loadMilliseconds = row.loadTime;
            visit.reappeared = row.reappeared;
            store(row.instance, visit);
        } else if (row.appeared == NRMATimelineAppearedNo && row.instance != nil
                   && visits[row.instance] != nil) {
            visits[row.instance].end = row.timestamp;
        }
    }

    for (NSArray *entry in marks) {
        [visits[entry[0]].marks addObject:entry[1]];
    }

    NSMutableArray<NRMASessionTimelineVisit *> *ordered = [NSMutableArray arrayWithCapacity:order.count];
    for (NSString *instance in order) [ordered addObject:visits[instance]];
    // Appear order, not arrival order: events arrive when visits end, so a parent that contains its
    // children's visits would otherwise be drawn after all of them.
    [ordered sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NRMASessionTimelineVisit *a, NRMASessionTimelineVisit *b) {
        if (a.appear < b.appear) return NSOrderedAscending;
        if (a.appear > b.appear) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSUInteger cut = 0;
    if (maximumVisits > 0 && ordered.count > maximumVisits) {
        cut = ordered.count - maximumVisits;
        [ordered removeObjectsInRange:NSMakeRange(maximumVisits, cut)];
    }
    if (dropped) *dropped = cut;
    return ordered;
}

- (BOOL)truncated { return _truncated; }

- (BOOL)isEmpty { return _rows.count == 0; }

@end
