//
//  NRMAFakeDataHelper.m
//  Agent
//
//  Created by Mike Bruin on 12/1/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAFakeDataHelper.h"
#import "NewRelicInternalUtils.h"
#import "NRLogger.h"

#import "NRMAExceptionhandlerConstants.h"

@implementation NRMAFakeDataHelper

+(BOOL) makeFakeCrashReport:(NSUInteger) size {
    // Write to temp file for upload.
    NSString* crashOutputFilePath = [NSString stringWithFormat:@"%@%@/%f.%@", NSTemporaryDirectory(), kNRMA_CR_ReportPath, NRMAMillisecondTimestamp(), kNRMA_CR_ReportExtension];
    NSError* error = nil;
    
    NSData *fakeCrashData = [self makeDataDictionary:size];

    if (![[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",NSTemporaryDirectory(),kNRMA_CR_ReportPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                         error:&error]) {
        NRLOG_VERBOSE(@"Failed to create crash report directory:  %@",error.description);
    }


     BOOL isWriteSuccessful = [[NSFileManager defaultManager] createFileAtPath:crashOutputFilePath
                                            contents:fakeCrashData
                                          attributes:nil];

    if (!isWriteSuccessful) {
        NRLOG_VERBOSE(@"failed to write crash report data to file.");
    }
    return isWriteSuccessful;
}

+(NSData*) makeDataDictionary:(NSUInteger) size {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc]init];
    for (int i = 0; i <= size; i++) {
        NSString *key = [[NSString alloc]initWithFormat:@"The meaning of life #%i", i];
        [dictionary setObject:@42 forKey:key];
    }
    NSData *fakeData = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
    return fakeData;
}

+(NSString *) makeStringOfSizeInBytes:(NSUInteger) size {
    NSMutableString * hugeString = [[NSMutableString alloc] init];
    NSUInteger bytes = [hugeString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    while(bytes < size){
        [hugeString appendString:@"THIS STRING IS GOING TO BE HUGE!!!! "];
        bytes = [hugeString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    }
    return hugeString;
}

@end
