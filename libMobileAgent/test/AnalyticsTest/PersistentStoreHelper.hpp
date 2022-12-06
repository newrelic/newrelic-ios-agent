//
// Created by Cameron Thomas on 4/28/15.
//

#include <sys/stat.h>

#ifndef PROJECT_PERSISTENTSTOREHELPER_HPP
#define PROJECT_PERSISTENTSTOREHELPER_HPP

class PersistentStoreHelper {

public:
    static bool storeExists(const char *storeName) {
        struct stat buffer;
        bool pathExists = (stat(storeName, &buffer) == 0);
        return pathExists;
    }

    static bool storeIsEmpty(const char *storeName) {
        struct stat buffer;
        bool pathExists = (stat(storeName, &buffer) == 0);
        if (pathExists) {
            return (0 == buffer.st_size);
        }
        return false;
    }

private:
    PersistentStoreHelper() {}

};

#endif //PROJECT_PERSISTENTSTOREHELPER_HPP
