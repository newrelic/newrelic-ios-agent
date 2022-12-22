//
//  NRMAURLSessionTaskSearch.m
//  NewRelicAgent
//
//  Created by Chris Dillard on 12/6/22.
//  Copyright (c) 2022 New Relic. All rights reserved.
//
#import "NRMAURLSessionTaskSearch.h"
#import <objc/runtime.h>

@implementation NRMAURLSessionTaskSearch

// Using same pattern from AFNetworkings code for URLSessionTask finding.
// https://github.com/AFNetworking/AFNetworking/blob/4eaec5b586ddd897ebeda896e332a62a9fdab818/AFNetworking/AFURLSessionManager.m#L349-L418.

+ (NSArray<Class> *)urlSessionTaskClasses {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *ephemeralSession = [NSURLSession sessionWithConfiguration:configuration];
    NSURLSessionDataTask *dataTaskClass = [ephemeralSession dataTaskWithURL:[NSURL URLWithString:@""]];

    Class currentClass = [dataTaskClass class];
    NSMutableArray *result = [[NSMutableArray alloc] init];

    SEL setStateSelector = NSSelectorFromString(@"setState:");

    while (class_getInstanceMethod(currentClass, setStateSelector)) {
        Class superClass = [currentClass superclass];
        IMP classResumeIMP = method_getImplementation(class_getInstanceMethod(currentClass, setStateSelector));
        IMP superIMP = method_getImplementation(class_getInstanceMethod(superClass, setStateSelector));
        if (classResumeIMP != superIMP) { [result addObject:currentClass]; }

        currentClass = [currentClass superclass];
    }

    [dataTaskClass cancel];
    [ephemeralSession finishTasksAndInvalidate];

    return [result copy];
}
@end
