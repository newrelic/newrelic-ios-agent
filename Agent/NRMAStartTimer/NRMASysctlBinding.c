//
//  NRMASysctlBinding.m
//
//  Created by Chris Dillard on 8/25/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#include "NRMASysctlBinding.h"

#include <stdlib.h>
#include <unistd.h>

struct timeval timeVal(const int majorCommand, const int minorCommand) {
    int cmd[2] = { majorCommand, minorCommand };
    struct timeval value = { 0 };
    size_t size = sizeof(value);

    if (0 != sysctl(cmd, sizeof(cmd) / sizeof(*cmd), &value, &size, NULL, 0)) {
        // ERROR
    }

    return value;
}

struct timeval processStartTime() {
    size_t length = 4;
    int mib[length];

    sysctlnametomib("kern.proc.pid", mib, &length);
    mib[3] = getpid();

    struct timeval value = { 0 };
    struct kinfo_proc kp;
    size_t kpSize = sizeof(kp);
    if (0 != sysctl(mib, 4, &kp, &kpSize, NULL, 0)) {
        // FAILED
    } else {
        value = kp.kp_proc.p_un.__p_starttime;
    }

    return value;
}
