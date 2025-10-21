//
//  NRMALoggerBridge.cpp
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/6/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "NRMALoggerBridge.hpp"
#include <stdarg.h>
#include <stdio.h>
#import "NRLogger.h"
namespace  NewRelic {
    
    void NRMALoggerBridge::log(unsigned int level,
                               const char* file,
                               unsigned int line,
                               const char* method,
                               const char* format,
                               va_list args) {

        //check file non-null
        if (file == nullptr || strlen(file) == 0) {
            file = "?";
        }

        //check method non-null
        if (method == nullptr || strlen(method) == 0) {
            method = "?";
        }

        //check format not null
        if (format == nullptr || strlen(format) == 0) {
            //can't write anything :P
            return;
        }

        va_list v2;

        va_copy(v2, args);

        int size = vsnprintf(NULL, 0, format, args);

        if (size < 0) {
            va_end(v2);
            return; //vsnprintf returns -1 if an error occurs.
        }
        
        // Prevent stack overflow from extremely large log messages
        const int MAX_STACK_BUFFER_SIZE = 4096; // 4KB max on stack
        char* buf = nullptr;
        
        if (size + 1 <= MAX_STACK_BUFFER_SIZE) {
            // Use stack allocation for small messages (safe, fast)
            char stackBuf[MAX_STACK_BUFFER_SIZE];
            buf = stackBuf;
            vsnprintf(buf, size + 1, format, v2);
            
            va_end(v2);

            [NRLogger log:level
                   inFile:[NSString stringWithUTF8String:file]
                   atLine:line
                 inMethod:[NSString stringWithUTF8String:method]
              withMessage:[NSString stringWithUTF8String:buf]
            withAgentLogsOn:YES];
        } else {
            // Use heap allocation for large messages (safe, prevents stack overflow)
            buf = (char*)malloc(size + 1);
            if (buf == nullptr) {
                va_end(v2);
                return; // Failed to allocate memory
            }
            
            vsnprintf(buf, size + 1, format, v2);
            va_end(v2);

            [NRLogger log:level
                   inFile:[NSString stringWithUTF8String:file]
                   atLine:line
                 inMethod:[NSString stringWithUTF8String:method]
              withMessage:[NSString stringWithUTF8String:buf]
            withAgentLogsOn:YES];
            
            free(buf);
        }
    }
}
