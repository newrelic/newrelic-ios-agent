//
// Created by Bryce Buchanan on 1/4/16.
//
#include "Utilities/LoggerBridge.hpp"
#include <stdio.h>
#include <stdarg.h>
namespace NewRelic {
    void DefaultLogger::log(unsigned int level, const char* file, unsigned int line, const char* method,
                            const char* format, va_list args) {

        va_list v2;

        va_copy(v2,args);

        int size = vsnprintf(NULL,0,format,args);

        if (size <= 0) return;

        char buf[size+1];

        va_end(args);

        vsnprintf(buf,sizeof(buf),format,v2);

        va_end(v2);

//         This is left as a no-op. It can be re-enabled for debugging purposes
//          printf("NewRelic:\t%s:%d in %s(...);\n\tmessage: \"%s\"\n",file,line,method,buf);
    }

    DefaultLogger::~DefaultLogger() {

    }
}

