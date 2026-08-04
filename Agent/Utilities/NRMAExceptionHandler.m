//
//  NRExceptionHandler.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAExceptionHandler.h"
#import "NRMAMeasurements.h"
#import "NRConstants.h"
#import "NRMATaskQueue.h"
#import "NRMAMetric.h"

@implementation NRMAExceptionHandler


+ (void) logException:(NSException*)exception
                class:(NSString*)cls
             selector:(NSString*)sel
{
    if (exception == nil || cls == nil || sel == nil) {
        NRLOG_AGENT_ERROR(@"%@ called with invalid parameters", NSStringFromClass([self class]));
        return;
    }

    if (![exception isKindOfClass:[NSException class]]) {
        NRLOG_AGENT_ERROR(@"%@ called with invalid parameter %@",NSStringFromClass([self class]),exception);
        return;
    }

    if (![cls isKindOfClass:[NSString class]]) {
        NRLOG_AGENT_ERROR(@"%@ called with invalid parameter as NSString",NSStringFromClass([self class]));
        return;
    }

    if (![sel isKindOfClass:[NSString class]]) {
        NRLOG_AGENT_ERROR(@"%@ called with invalid parameter as NSString",NSStringFromClass([self class]));
        return;
    }


    @try {
    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:@"%@/Exception/%@/%@/%@",kNRAgentHealthPrefix,cls,sel,exception.name]
                               value:@1
                           scope:nil]];
    } @catch (NSException* exception) {
        // Something went wrong.
    }
}

+ (BOOL) safelyRun:(NS_NOESCAPE void(^)(void))block
             error:(NSError * _Nullable * _Nullable)error
{
    if (block == nil) { return YES; }
    @try {
        block();
        return YES;
    } @catch (NSException *ex) {
        if (error != NULL) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            if (ex.name)   info[@"NSExceptionName"]   = ex.name;
            if (ex.reason) info[NSLocalizedDescriptionKey] = ex.reason;
            *error = [NSError errorWithDomain:@"com.newrelic.sessionreplay"
                                         code:-1
                                     userInfo:info];
        }
        return NO;
    }
}

@end
