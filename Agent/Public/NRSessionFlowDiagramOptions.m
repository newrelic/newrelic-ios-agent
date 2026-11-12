//
//  NRSessionFlowDiagramOptions.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRSessionFlowDiagramOptions.h"

@implementation NRSessionFlowDiagramOptions

+ (instancetype)defaultOptions {
    return [[self alloc] init];
}

- (instancetype)init {
    if ((self = [super init])) {
        _includeComponents = NO;
        _includeBreadcrumbs = NO;
        _includeTimings = YES;
        _includeRouteTimings = YES;
        _minimumTransitionCount = 1;
        _slowLoadThresholdMilliseconds = 500.0;
        _lieWindowThresholdMilliseconds = 250.0;
        _leafFoldingThreshold = 6;
        _maximumTimelineVisits = 25;
        _timelineAxisFormat = @"%M:%S";
        _title = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    NRSessionFlowDiagramOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.includeComponents = _includeComponents;
    copy.includeBreadcrumbs = _includeBreadcrumbs;
    copy.includeTimings = _includeTimings;
    copy.includeRouteTimings = _includeRouteTimings;
    copy.minimumTransitionCount = _minimumTransitionCount;
    copy.slowLoadThresholdMilliseconds = _slowLoadThresholdMilliseconds;
    copy.lieWindowThresholdMilliseconds = _lieWindowThresholdMilliseconds;
    copy.leafFoldingThreshold = _leafFoldingThreshold;
    copy.maximumTimelineVisits = _maximumTimelineVisits;
    copy.timelineAxisFormat = _timelineAxisFormat;
    copy.title = _title;
    return copy;
}

@end
