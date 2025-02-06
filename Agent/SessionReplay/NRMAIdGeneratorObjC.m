//
//  NRMAIdGenerator.m
//  Agent_iOS
//
//  Created by Steve Malsam on 3/5/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAIdGeneratorObjC.h"

@implementation NRMAIdGeneratorObjC


static NSInteger counter = 0;

+ (NSInteger)generateID {
    return counter++;
}

@end
