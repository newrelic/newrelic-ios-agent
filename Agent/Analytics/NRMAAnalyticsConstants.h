//
//  NRMAAnalytics.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/5/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* userIdReservedKey = @"userId";
static NSString* lastInteractionReservedKey = @"lastInteraction";

#define reservedKeywords  [NSArray arrayWithObjects: @"eventType",@"type",@"timestamp",@"category",@"accountId",@"appId",@"appName",@"uuid",@"sessionDuration",@"osName",@"osVersion",@"osMajorVersion",@"deviceManufacturer",@"deviceModel",@"carrier",@"newRelicVersion",@"memUsageMb",@"sessionId",@"install",@"upgradeFrom",@"platform",@"platformVersion",@"lastInteraction",nil]

static int maxNameLength = 256;
static int maxValueSizeBytes = 4096;
static int maxNumberAttributes = 128;

static NSString *attributesFileName = @"attributes.txt";
static NSString *privateAttributesFileName = @"privateAttributes.txt";
