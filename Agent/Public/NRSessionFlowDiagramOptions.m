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
        _includeComponents = YES;
        _includeBreadcrumbs = YES;
        _minimumTransitionCount = 1;
        _slowLoadThresholdMilliseconds = 500.0;
        _title = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    NRSessionFlowDiagramOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.includeComponents = _includeComponents;
    copy.includeBreadcrumbs = _includeBreadcrumbs;
    copy.minimumTransitionCount = _minimumTransitionCount;
    copy.slowLoadThresholdMilliseconds = _slowLoadThresholdMilliseconds;
    copy.title = _title;
    return copy;
}

@end
