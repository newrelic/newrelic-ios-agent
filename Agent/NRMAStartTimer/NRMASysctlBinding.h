//
//  NRMASysctlBinding.h
//
//  Created by Chris Dillard on 8/25/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <sys/sysctl.h>

struct timeval timeVal(int major_cmd, int minor_cmd);
struct timeval processStartTime(void);

#ifdef __cplusplus
}
#endif
