//
//  NRMAURLSessionTaskSearch.m
//  NewRelicAgent
//
//  Created by Chris Dillard on 12/6/22.
//  Copyright © 2023 New Relic. All rights reserved.
//
#import "NRMAURLSessionTaskSearch.h"
#import <objc/runtime.h>

@implementation NRMAURLSessionTaskSearch

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
