//
//  NRMAExceptionDataWrapper.c
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//


#import "NRMAExceptionMetaDataStore.h"
#include <fcntl.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <errno.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/utsname.h>
#include <pthread.h>
#import <time.h>


#define MILLI_PER_SECOND 1000
#define NANO_PER_MILLI 1000000


#ifdef __cplusplus
extern "C" {
#endif

#import "NewRelicInternalUtils.h"
#include "NRMAInteractionHistory.h"

    void NRMA_writeInteractionHistory(int fd);
    void NRMA_writeCrashTime(int fd);

    ssize_t NRMA_write(int fd, const void* data, size_t len);

#pragma mark - Signal-safe metadata fields

    // Every string field below is read from inside the PLCrashReporter BSD signal
    // handler (NRMA_writeNRMeta) and written from arbitrary agent threads. That
    // combination rules out both heap churn and blocking locks on the read path:
    //
    //  * malloc/free are not async-signal-safe. The previous implementation
    //    malloc'd a replacement string and free'd the old one on every setter
    //    call, so a crash that happened while any thread held the malloc lock --
    //    including a crash caused by this code -- could deadlock the handler and
    //    lose the report entirely. Two threads setting the same field also raced
    //    to free the same old pointer, which is the libmalloc "pointer being
    //    freed was not allocated" abort seen in the field.
    //  * a pthread mutex on the read path can deadlock the handler outright if
    //    the crashing thread was already holding it.
    //
    // So each field owns two permanently allocated slots plus a monotonically
    // increasing generation counter. A writer fills the slot readers are not
    // looking at and publishes it with a single release store; a reader takes one
    // acquire load and follows it. Nothing is ever allocated or freed, so a
    // double free is not expressible and a reader can never hold a dangling
    // pointer.
    //
    // Each slot is declared one byte longer than its usable capacity and writers
    // never touch that final byte, so the guard byte stays NUL for the life of
    // the process. Every read is therefore bounded even when it races a write;
    // the worst case is a truncated or momentarily stale value, never an
    // out-of-bounds read.

#define NRMA_META_CAP_PATH  1024 // temp directory
#define NRMA_META_CAP_TOKEN  256 // application token
#define NRMA_META_CAP_NAME   256 // app name, version, build, build identifier
#define NRMA_META_CAP_UUID    64 // session id
#define NRMA_META_CAP_MODEL   64 // device model
#define NRMA_META_CAP_SHORT   32 // numeric values, connectivity
#define NRMA_META_CAP_TINY    16 // orientation

    typedef struct {
        _Atomic uint32_t generation; // 0 == unset; the live slot is (generation & 1)
        size_t capacity;             // greatest strlen a slot can hold
        char* slot[2];               // each points at capacity + 1 bytes
    } NRMAMetaStringField;

#define NRMA_DEFINE_META_FIELD(ident, cap)                                    \
    static char ident##_storage[2][(cap) + 1];                                \
    static NRMAMetaStringField ident = {                                      \
        .generation = 0,                                                      \
        .capacity = (cap),                                                    \
        .slot = { ident##_storage[0], ident##_storage[1] }                     \
    }

    NRMA_DEFINE_META_FIELD(__tempDirectory,      NRMA_META_CAP_PATH);
    NRMA_DEFINE_META_FIELD(__sessionId,          NRMA_META_CAP_UUID);
    NRMA_DEFINE_META_FIELD(__appToken,           NRMA_META_CAP_TOKEN);
    NRMA_DEFINE_META_FIELD(__appVersion,         NRMA_META_CAP_NAME);
    NRMA_DEFINE_META_FIELD(__appName,            NRMA_META_CAP_NAME);
    NRMA_DEFINE_META_FIELD(__buildIdentifier,    NRMA_META_CAP_NAME);
    NRMA_DEFINE_META_FIELD(__build,              NRMA_META_CAP_NAME);
    NRMA_DEFINE_META_FIELD(__orientation,        NRMA_META_CAP_TINY);
    NRMA_DEFINE_META_FIELD(__memoryUsage,        NRMA_META_CAP_SHORT);
    NRMA_DEFINE_META_FIELD(__memorySize,         NRMA_META_CAP_SHORT);
    NRMA_DEFINE_META_FIELD(__modelNumber,        NRMA_META_CAP_MODEL);
    NRMA_DEFINE_META_FIELD(__diskSize,           NRMA_META_CAP_SHORT);
    NRMA_DEFINE_META_FIELD(__networkConnectivity, NRMA_META_CAP_SHORT);
    NRMA_DEFINE_META_FIELD(__sessionStartTime,   NRMA_META_CAP_SHORT);

    static _Atomic uint64_t __diskFree = 0;
    static _Atomic uint64_t __accountId = 0;
    static _Atomic uint64_t __agentId = 0;

    // Serializes writers against each other so two threads targeting the same
    // field cannot interleave bytes into the same slot. Never taken on the read
    // path, and never taken from the crash handler -- see the note above.
    static pthread_mutex_t __nrma_meta_writer_lock = PTHREAD_MUTEX_INITIALIZER;

    static void NRMA_metaStringSet(NRMAMetaStringField* field, const char* src)
    {
        if (field == NULL || src == NULL) {
            // A NULL source leaves the current value in place. Callers routinely
            // pass -[NSString UTF8String] of an optional string, and dropping the
            // update is better than clearing metadata the report still needs.
            return;
        }

        pthread_mutex_lock(&__nrma_meta_writer_lock);

        uint32_t generation = atomic_load_explicit(&field->generation, memory_order_relaxed);
        uint32_t next = generation + 1;
        if (next == 0) {
            // 0 is reserved for "unset". Skipping to 2 also keeps the slot parity
            // alternating, so the next write still avoids the slot readers hold.
            next = 2;
        }

        char* target = field->slot[next & 1u];
        size_t length = strnlen(src, field->capacity);
        memcpy(target, src, length);
        target[length] = '\0';

        atomic_store_explicit(&field->generation, next, memory_order_release);

        pthread_mutex_unlock(&__nrma_meta_writer_lock);
    }

    static const char* NRMA_metaStringGet(NRMAMetaStringField* field)
    {
        if (field == NULL) {
            return NULL;
        }

        uint32_t generation = atomic_load_explicit(&field->generation, memory_order_acquire);
        if (generation == 0) {
            return NULL; // never set: preserves the historical getter contract
        }

        return field->slot[generation & 1u];
    }

    static void NRMA_metaStringReset(NRMAMetaStringField* field)
    {
        if (field == NULL) {
            return;
        }

        // Async-signal-safe: one atomic store, no lock and no deallocation. The
        // slots are permanent, so marking the field unset invalidates nothing
        // that another thread could still be reading.
        //
        // Two deliberate consequences of not taking the writer lock here. A setter
        // that already loaded the generation can publish after this store, which
        // just means the set happened after the clear. And resetting to 0 restarts
        // the slot parity, so the next write lands on the slot a reader may still
        // be walking. Neither is a safety problem: the slots never move and their
        // guard byte is always NUL, so the worst outcome is a garbled value read
        // out of a process that has already crashed.
        atomic_store_explicit(&field->generation, 0, memory_order_release);
    }

#pragma mark - Accessors

    void NRMA_setAgentId(uint64_t agentId)
    {
        atomic_store_explicit(&__agentId, agentId, memory_order_release);
    }

    uint64_t NRMA_getAgentId(void) {
        return atomic_load_explicit(&__agentId, memory_order_acquire);
    }

    void NRMA_setAccountId(uint64_t accountId)
    {
        atomic_store_explicit(&__accountId, accountId, memory_order_release);
    }

    uint64_t NRMA_getAccountId(void)
    {
        return atomic_load_explicit(&__accountId, memory_order_acquire);
    }

    void NRMA_setSessionId(const char* sessionId) {
        NRMA_metaStringSet(&__sessionId, sessionId);
    }

    const char* NRMA_getSessionId(void) {
        return NRMA_metaStringGet(&__sessionId);
    }

    //AppToken

    void NRMA_setTempDir(const char* tempDir)
    {
        NRMA_metaStringSet(&__tempDirectory, tempDir);
    }

    const char* NRMA_getTempDir(void)
    {
        return NRMA_metaStringGet(&__tempDirectory);
    }

    void NRMA_setAppToken(const char* appToken)
    {
        NRMA_metaStringSet(&__appToken, appToken);
    }

    const char* NRMA_getAppToken(void)
    {
        return NRMA_metaStringGet(&__appToken);
    }

    //AppVersion
    void NRMA_setAppVersion(const char* appVersion)
    {
        NRMA_metaStringSet(&__appVersion, appVersion);
    }

    const char* NRMA_getAppVersion(void)
    {
        return NRMA_metaStringGet(&__appVersion);
    }

    //AppName
    void NRMA_setAppName(const char* appName)
    {
        NRMA_metaStringSet(&__appName, appName);
    }

    const char* NRMA_getAppName(void)
    {
        return NRMA_metaStringGet(&__appName);
    }

    //BuildIdentifier
    void NRMA_setBuildIdentifier(const char* buildIdentifier)
    {
        NRMA_metaStringSet(&__buildIdentifier, buildIdentifier);
    }

    const char* NRMA_getBuildIdentifier(void)
    {
        return NRMA_metaStringGet(&__buildIdentifier);
    }

    //orientation
    void NRMA_setOrientation(const char* orientation)
    {
        NRMA_metaStringSet(&__orientation, orientation);
    }

    const char* NRMA_getOrientation(void)
    {
        return NRMA_metaStringGet(&__orientation);
    }

    //memoryUsage
    void NRMA_setMemoryUsage(const char* memoryUsage)
    {
        NRMA_metaStringSet(&__memoryUsage, memoryUsage);
    }

    const char* NRMA_getMemoryUsage(void)
    {
        return NRMA_metaStringGet(&__memoryUsage);
    }

    //memorySize
    void NRMA_setMemorySize(const char* memorySize)
    {
        NRMA_metaStringSet(&__memorySize, memorySize);
    }

    const char* NRMA_getMemorySize(void)
    {
        return NRMA_metaStringGet(&__memorySize);
    }

    //DiskUsage

    void NRMA_setDiskSize(const char* diskSize)
    {
        NRMA_metaStringSet(&__diskSize, diskSize);
    }

    const char* NRMA_getDiskSize(void)
    {
        return NRMA_metaStringGet(&__diskSize);
    }

    void NRMA_setDiskFree(uint64_t diskFree)
    {
        atomic_store_explicit(&__diskFree, diskFree, memory_order_release);
    }

    uint64_t NRMA_getDiskFree(void)
    {
        return atomic_load_explicit(&__diskFree, memory_order_acquire);
    }

    //NetworkConnectivity

    void NRMA_setNetworkConnectivity(const char* networkConnectivity)
    {
        NRMA_metaStringSet(&__networkConnectivity, networkConnectivity);
    }

    const char* NRMA_getNetworkConnectivity(void)
    {
        return NRMA_metaStringGet(&__networkConnectivity);
    }


void NRMA_setBuild(const char* buildNumber)
{
    NRMA_metaStringSet(&__build, buildNumber);
}

    const char* NRMA_getBuild(void)
{
    return NRMA_metaStringGet(&__build);
}

//SessionStartTime
    void NRMA_setSessionStartTime(const char* sessionStartTime)
    {
        NRMA_metaStringSet(&__sessionStartTime, sessionStartTime);
    }

    const char* NRMA_getSessionStartTime(void)
    {
        return NRMA_metaStringGet(&__sessionStartTime);
    }

    void NRMA__freeMetaData(void)
    {
        // Marks every field unset. Retained for its historical name and call
        // sites; there is no longer any memory to release.
        NRMA_metaStringReset(&__sessionId);
        NRMA_metaStringReset(&__tempDirectory);
        NRMA_metaStringReset(&__appToken);
        NRMA_metaStringReset(&__appVersion);
        NRMA_metaStringReset(&__appName);
        NRMA_metaStringReset(&__buildIdentifier);
        NRMA_metaStringReset(&__build);
        NRMA_metaStringReset(&__orientation);
        NRMA_metaStringReset(&__memoryUsage);
        NRMA_metaStringReset(&__memorySize);
        NRMA_metaStringReset(&__modelNumber);
        NRMA_metaStringReset(&__diskSize);
        NRMA_metaStringReset(&__networkConnectivity);
        NRMA_metaStringReset(&__sessionStartTime);
    }

    void NRMA_freeInteractionHistoryList(void) {
        NRMA__clearInteractionHistory();
    }

    void NRMA_freeExceptionData(void) {
        NRMA__freeMetaData();
        NRMA_freeInteractionHistoryList();
    }

#pragma mark - Serialization

    int NRMA_writeCharValue(int fd, const char *name, const char *value) {
        if (name == NULL || value == NULL)
            return 0;

        size_t nameLen = strlen(name);
        size_t valueLen = strlen(value);

        ssize_t ret;
        ret = NRMA_write(fd, name, nameLen);
        if (ret != (ssize_t)nameLen)
            return -1;

        ret = NRMA_write(fd, ":", 1);
        if (ret != 1)
            return -1;

        ret = NRMA_write(fd, value, valueLen);
        if (ret != (ssize_t)valueLen)
            return -1;

        ret = NRMA_write(fd, "\n", 1);
        if (ret != 1)
            return -1;

        return 0;
    }

    int NRMA_writeUInt64Value(int fd, const char *name, uint64_t value) {
        if (name == NULL)
            return 0;

        size_t nameLen = strlen(name);
        size_t valueSize = sizeof(value);

        ssize_t ret;
        ret = NRMA_write(fd, name, nameLen);
        if (ret != (ssize_t)nameLen)
            return -1;

        ret = NRMA_write(fd, ":", 1);
        if (ret != 1)
            return -1;

        ret = NRMA_write(fd, &value, valueSize);
        if (ret != (ssize_t)valueSize)
            return -1;

        ret = NRMA_write(fd, "\n", 1);
        if (ret != 1)
            return -1;

        return 0;
    }

    // Largest path NRMA_formatTempFileName can produce: the temp directory, an
    // optional separator, the file name, and the terminator.
#define NRMA_META_TEMP_FILE_PATH_CAPACITY (NRMA_META_CAP_PATH + sizeof(kNRMAMetaFileName) + 2)

    // Composes "<tempdir>/metadata.nr.crash" into caller-supplied storage.
    // Allocation-free and bounded, so it is safe to call from the crash handler.
    // Returns the length written, or 0 when the temp directory is unset or the
    // composed path will not fit. `out` is always NUL-terminated.
    static size_t NRMA_formatTempFileName(char* out, size_t outSize)
    {
        if (out == NULL || outSize == 0) {
            return 0;
        }
        out[0] = '\0';

        const char* tempDir = NRMA_getTempDir();
        if (tempDir == NULL || tempDir[0] == '\0') {
            // Without a temp directory there is nowhere to put the metadata.
            // Falling back to a relative path would scatter crash files through
            // whatever the process working directory happens to be.
            return 0;
        }

        size_t dirLen = strlen(tempDir);
        size_t nameLen = strlen(kNRMAMetaFileName);

        // NSTemporaryDirectory() already ends in '/', but a directory set through
        // NRMA_setTempDir() need not, and concatenating without a separator then
        // yields "/some/dirmetadata.nr.crash". dirLen >= 1 here because the empty
        // case returned above.
        bool needsSeparator = (tempDir[dirLen - 1] != '/');
        size_t total = dirLen + (needsSeparator ? 1 : 0) + nameLen;

        if (total + 1 > outSize) {
            return 0;
        }

        memcpy(out, tempDir, dirLen);
        size_t offset = dirLen;
        if (needsSeparator) {
            out[offset++] = '/';
        }
        memcpy(out + offset, kNRMAMetaFileName, nameLen);
        offset += nameLen;
        out[offset] = '\0';

        return offset;
    }

    const char *NRMA_createTempFileName(void) {
        char path[NRMA_META_TEMP_FILE_PATH_CAPACITY];

        size_t length = NRMA_formatTempFileName(path, sizeof(path));
        if (length == 0) {
            return NULL;
        }

        // Callers own the returned string and free() it.
        char *fileName = (char *)malloc(length + 1);
        if (fileName == NULL) {
            return NULL;
        }
        memcpy(fileName, path, length + 1);

        return fileName;
    }

    void NRMA_writeMetaValues(int fd) {
        if(NRMA_writeCharValue(fd, kNRMAMetaKey_AppName, NRMA_getAppName()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_AppToken, NRMA_getAppToken()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_AppVersion, NRMA_getAppVersion()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_Build, NRMA_getBuild()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_BuildId, NRMA_getBuildIdentifier()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_MemoryUse, NRMA_getMemoryUsage()) == -1)
            return;

        if (NRMA_writeCharValue(fd, kNRMAMetaKey_ModelNumber, NRMA_getModelNumber()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_Orientation, NRMA_getOrientation()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_NetworkConnectivity, NRMA_getNetworkConnectivity()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_SessionStartTime, NRMA_getSessionStartTime()) == -1)
            return;

        if(NRMA_writeUInt64Value(fd, kNRMAMetaKey_DiskFree, NRMA_getDiskFree()) == -1)
            return;

        if(NRMA_writeUInt64Value(fd, kNRMAMetaKey_AccountId, NRMA_getAccountId()) == -1)
            return;

        if(NRMA_writeUInt64Value(fd, kNRMAMetaKey_AgentId, NRMA_getAgentId()) == -1)
            return;

        if(NRMA_writeCharValue(fd, kNRMAMetaKey_Session, NRMA_getSessionId()) == -1)
            return;
     }

    void NRMA_writeNRMeta(siginfo_t *info, ucontext_t *uap, void *context)
    {
        // Runs from the PLCrashReporter BSD signal handler. Everything below has
        // to be async-signal-safe, which is why the path is composed into static
        // storage instead of being malloc'd: the crash being reported may well
        // have happened inside malloc, and taking the malloc lock here would
        // hang the handler and lose the report.
        static char tempFileName[NRMA_META_TEMP_FILE_PATH_CAPACITY];

        if (NRMA_formatTempFileName(tempFileName, sizeof(tempFileName)) == 0) {
            return;
        }

        int fd = open(tempFileName, O_CREAT | O_TRUNC | O_WRONLY, 0755);

        if (fd == -1) {
            //sad day.
            return;
        }
        NRMA_writeMetaValues(fd);
        NRMA_writeInteractionHistory(fd);
        NRMA_writeCrashTime(fd);

        close(fd);

        NRMA_freeExceptionData();
    }

    void NRMA_writeInteractionHistory(int fd)
    {
        // Snapshot first so the set of interactions cannot change underneath the
        // loop, then copy each one out. Newest first, matching the order the
        // previous linked-list implementation produced.
        NRMAInteractionHistorySnapshot snapshot = NRMA__snapshotInteractionHistory();

        size_t txnKeyLen = strlen(kNRMAMetaKey_Transactions);
        ssize_t ret;

        ret = NRMA_write(fd, kNRMAMetaKey_Transactions, txnKeyLen);
        if (ret != (ssize_t)txnKeyLen)
            return;

        ret = NRMA_write(fd, ":", 1);
        if (ret != 1)
            return;

        for (uint32_t index = 0; index < snapshot.count; index++) {
            char name[NRMA_INTERACTION_NAME_CAPACITY + 1];
            long long timestampMillis = 0;

            if (!NRMA__readInteraction(snapshot, index, name, sizeof(name), &timestampMillis)) {
                continue;
            }

            size_t len = strlen(name);
            if (len == 0) {
                continue;
            }

            if (NRMA_write(fd, name, len) != (ssize_t)len)
                return;

            if (NRMA_write(fd, ";", 1) != 1)
                return;

            ret = NRMA_write(fd, &timestampMillis, sizeof(timestampMillis));
            if (ret != (ssize_t)sizeof(timestampMillis))
                return;
        }
        NRMA_write(fd, "\n", 1);
    }

    void NRMA_writeCrashTime(int fd) {
        time_t t;
        // Use time(), it's fast (~4 cycles).
        time(&t);
        // If we take too long calculating the time the app will terminate.
        // Add 1 second due to loss of ms accuracy. this makes all calculated values more accurate.
        NRMA_writeUInt64Value(fd, kNRMAMetaKey_CrashTime, t+1);
    }

    // Not async safe, don't call in crash handler.
    // This is now only called on harvest before.

    void NRMA_updateModelNumber(void)
    {

        NSString* model = [NewRelicInternalUtils deviceModel];

        if ([model length]) {
            NRMA_metaStringSet(&__modelNumber, model.UTF8String);
        }

        return;
    }

    const char* NRMA_getModelNumber(void)
    {
        return NRMA_metaStringGet(&__modelNumber);
    }

    void NRMA_updateDiskUsage(void)
    {
        struct statfs mystat;

        int result = statfs("/", &mystat);

        uint64_t diskFree = 0;
        if (result == 0) {
            diskFree = ((uint64_t)mystat.f_bfree * (uint64_t)mystat.f_bsize);
        }

        NRMA_setDiskFree(diskFree);
    }

    ssize_t NRMA_write(int fd, const void* data, size_t len)
    {
        if (data == NULL) {
            return -1;
        }

        const char* cursor = (const char*)data;
        size_t remaining = len;

        while (remaining > 0) {
            ssize_t written = write(fd, cursor, remaining);
            if (written < 0) {
                if (errno == EINTR) {
                    continue; // interrupted before any bytes moved; retry
                }
                return -1;
            }
            if (written == 0) {
                return -1; // no progress, and looping would spin forever
            }
            remaining -= (size_t)written;
            cursor += written;
        }

        // Callers compare this against the length they asked for, so report the
        // total. The previous implementation returned the size of the final
        // write() only, which made every caller treat a partial write as a
        // failure and silently truncate the metadata file.
        return (ssize_t)len;
    }

#ifdef __cplusplus
}
#endif // extern "C" {
