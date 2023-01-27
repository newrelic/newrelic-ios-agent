//
// Created by Bryce Buchanan on 1/4/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <stdarg.h>
#include <memory>
#include <Utilities/libLogger.hpp>
namespace NewRelic {
    static std::shared_ptr<LoggerBridge> __bridge = std::shared_ptr<LoggerBridge>(new DefaultLogger());

    void LibLogger::setLogger(std::shared_ptr<LoggerBridge> bridge) {
        __bridge = bridge;
    }

    void LibLogger::log(enum LLogLevel level,
                               const char* file,
                               unsigned int line,
                               const char* method,
                               const char* format,
                               ...) {
       if( __bridge != nullptr) {
           va_list argv;
           va_start(argv, format);
           __bridge->log(level,file,line,method,format,argv);
           va_end(argv);
       }
    }
}
