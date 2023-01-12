//
//  NRMANonARCMethods.m
//  NewRelicAgent
//
//  Created by Jonathan Karon on 10/30/12.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMANonARCMethods.h"

@implementation NRMANonARCMethods

+ (NSInteger)OSMajorVersion
{
    NSString *version = [[UIDevice currentDevice] systemVersion];
    NSArray *components = [version componentsSeparatedByString:@"."];
    if (components.count > 1) {
        return [[components objectAtIndex:0] integerValue];
    }
    else {
        return 0;
    }
}

+ (NSInteger)OSMinorVersion
{
    NSString *version = [[UIDevice currentDevice] systemVersion];
    NSArray *components = [version componentsSeparatedByString:@"."];
    if (components.count > 1) {
        return [[components objectAtIndex:1] integerValue];
    }
    else {
        return 0;
    }
}

@end
