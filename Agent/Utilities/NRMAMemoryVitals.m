//
//  NRMAMemoryVitals.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/7/14.
//  Copyright (c) 2014 New Relic. All rights reserved.
//

#import "NRMAMemoryVitals.h"
#import <mach/mach.h>
#import "NRLogger.h"
#import "NewRelicInternalUtils.h"
#import "NRConstants.h"
#define BYTES_PER_MB            1048576.0
#define NRMAMemoryCacheDuration 1000
@implementation NRMAMemoryVitals
static NSString *__NRMAMemoryVitalsLock = @"NRMAMemoryVitalsLock";
static double __lastCachedMillis;
static double __lastCachedMemoryUsage;

// http://www.samirchen.com/ios-app-memory-usage/
+ (double) memoryUseInMegabytes {

    @synchronized(__NRMAMemoryVitalsLock) {
        double currentTime = NRMAMillisecondTimestamp();
        if (currentTime < __lastCachedMillis + NRMAMemoryCacheDuration ) {
            return __lastCachedMemoryUsage;
        }
        __lastCachedMillis = currentTime;

        task_vm_info_data_t vmInfo;
        mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
        if(kernelReturn == KERN_SUCCESS) {
            __lastCachedMemoryUsage = (float)vmInfo.phys_footprint / BYTES_PER_MB;
            [[NSNotificationCenter defaultCenter] postNotificationName:kNRMemoryUsageDidChangeNotification
                                                                object:@(__lastCachedMemoryUsage)];

            return __lastCachedMemoryUsage;
        } else {
            NRLOG_ERROR(@"Error with task_info(): %s", mach_error_string(kernelReturn));
            return 0;
        }
    }
}

@end
