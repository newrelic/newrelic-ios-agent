//
//  NRMAExceptionMetaDataTest.m
//  NewRelicAgent
//
//  Created by Jared Stanbrough on 5/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAExceptionMetaDataStore.h"
#include <sys/utsname.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#import "NRMAInteractionHistory.h"
#import "NewRelicInternalUtils.h"
#include <sys/socket.h>

// Internal to NRMAExceptionMetaDataStore.m and deliberately not in its header,
// but exercised directly here because these are the entry points the crash
// handler uses.
extern void NRMA__freeMetaData(void);
extern int NRMA_writeCharValue(int fd, const char *name, const char *value);
extern ssize_t NRMA_write(int fd, const void* data, size_t len);

// Reads a metadata value the same way the crash handler does: take the pointer,
// then walk it. Faults if a concurrent setter freed the value underneath us.
static void NRMAReadMetaValue(const char* value)
{
    if (value == NULL) {
        return;
    }
    volatile size_t length = strlen(value);
    (void)length;
}

@interface NRMAExceptionMetaDataTest : XCTestCase

@end

@implementation NRMAExceptionMetaDataTest

- (void)setUp
{
    [super setUp];
    // The metadata store and the interaction history are process-wide, so clear
    // both between tests. Without this, a test that sets a field the crash
    // metadata assertions do not set (build, sessionid) changes the bytes a
    // later test expects.
    NRMA__freeMetaData();
    NRMA__clearInteractionHistory();
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// test 
- (void)test_NRMA_writeNRMeta
{

    NRMA_setTempDir("./");

    const char *tempFile = NRMA_createTempFileName();



    char buff[500];

    getcwd(buff, 500);
    
    NSLog(@"tempfile path: %s",tempFile);

    // The metadata store records the model number via +[NewRelicInternalUtils deviceModel],
    // which on the simulator returns the simulated device identifier with "simulator-"
    // appended (rather than the host arch from uname). Derive the expected value from the
    // same source so this test stays correct on both simulators and real devices.
    const char* machineName = [NewRelicInternalUtils deviceModel].UTF8String;

    remove(tempFile);


    NRMA_setAppName("test");
    NRMA_setAppToken("abc123");
    NRMA_setAppVersion("1.0");
    NRMA_setBuildIdentifier("01234");
    NRMA_setMemoryUsage("128");
    NRMA_updateModelNumber();
    NRMA_setOrientation("portrait");
    NRMA_setNetworkConnectivity("wifi");
    NRMA_setSessionStartTime("1234");
    NRMA_setDiskFree(123456);
    NRMA_setAccountId(2);
    NRMA_setAgentId(1);


    // Add interactions.

    long long interactionTime = 1000;
    NSString* interactionName = @"TestTrace";
    NRMA__AddInteraction(interactionName.UTF8String, interactionTime);
    long long interactionTime2 = 2000;
    NSString* interactionName2 = @"TestTrace2";
    NRMA__AddInteraction(interactionName2.UTF8String, interactionTime2);

    NRMA_writeNRMeta(NULL, NULL, NULL);


    int fd = open(tempFile, O_RDONLY, 0655);
    if (fd == -1) {
        NSLog(@"%d : %s",errno, strerror(errno));
        return;
    }
    XCTAssertFalse(fd == -1, @"can't open tempfile: %s", tempFile);
    
    struct stat tempStat;
    ssize_t err = stat(tempFile, &tempStat);
    XCTAssertFalse(err < 0, @"Failed to stat temp file");

    char *metaData = (char *)malloc((unsigned long)tempStat.st_size);
    XCTAssertFalse(metaData == NULL, @"Failed to alloc space for crash metadata");

    err = read(fd, metaData, (size_t)tempStat.st_size);
    XCTAssertTrue(err == tempStat.st_size, @"Failed to sizread all crash metadata");
//@\xe2\x01
//    const char* expectedData = [NSString stringWithFormat:].UTF8String;
    char buf[256];
    snprintf(buf, 255, "appname:test\napptoken:abc123\nappversion:1.0\nbuildidentifier:01234\nmemoryusage:128\nmodelnumber:%s\norientation:portrait\nnetworkconnectivity:wifi\nsessionstarttime:1234\ndiskfree:@\xe2\x01",machineName);
    XCTAssertTrue(strcmp(metaData,buf) == 0, @"Expecting different meta data");
    
    free((void *)metaData);
    free((void *)tempFile);
}

#pragma mark - Metadata store concurrency

// Regression test for NR-603379 / NR-603422.
//
// The field crash was a libmalloc abort -- "pointer being freed was not
// allocated" -- inside the metadata store's setter, reached from two threads
// running -[NewRelicAgentInternal onSessionStart] at the same time. The setter
// read the old pointer, freed it and stored the new one with no
// synchronization, so both threads freed the same pointer.
//
// Serializing that swap closes one window but not the rest: the getters still
// handed out a pointer that a concurrent setter was about to free, and
// NRMA__freeMetaData() freed every field with no synchronization at all. This
// test drives all three at once -- every setter, every getter, and a repeated
// clear -- so it fails on any implementation that still owns these values on the
// heap.
- (void)test_metaDataStore_concurrentSettersGettersAndClearDoNotCorruptTheHeap
{
    const NSUInteger writerCount = 8;
    const NSUInteger readerCount = 4;
    const NSUInteger iterations = 4000;

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSUInteger w = 0; w < writerCount; w++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger i = 0; i < iterations; i++) {
                @autoreleasepool {
                    NSString* value = [NSString stringWithFormat:@"w%lu-i%lu",
                                       (unsigned long)w, (unsigned long)i];
                    const char* utf8 = value.UTF8String;

                    // Every field, so the writers collide on each in turn.
                    NRMA_setSessionId(utf8);
                    NRMA_setSessionStartTime(utf8);
                    NRMA_setAppToken(utf8);
                    NRMA_setAppVersion(utf8);
                    NRMA_setAppName(utf8);
                    NRMA_setBuild(utf8);
                    NRMA_setBuildIdentifier(utf8);
                    NRMA_setOrientation(utf8);
                    NRMA_setMemoryUsage(utf8);
                    NRMA_setMemorySize(utf8);
                    NRMA_setDiskSize(utf8);
                    NRMA_setNetworkConnectivity(utf8);
                    NRMA_setTempDir(utf8);
                }
            }
        });
    }

    for (NSUInteger r = 0; r < readerCount; r++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger i = 0; i < iterations; i++) {
                NRMAReadMetaValue(NRMA_getSessionId());
                NRMAReadMetaValue(NRMA_getSessionStartTime());
                NRMAReadMetaValue(NRMA_getAppToken());
                NRMAReadMetaValue(NRMA_getAppVersion());
                NRMAReadMetaValue(NRMA_getAppName());
                NRMAReadMetaValue(NRMA_getBuild());
                NRMAReadMetaValue(NRMA_getBuildIdentifier());
                NRMAReadMetaValue(NRMA_getOrientation());
                NRMAReadMetaValue(NRMA_getMemoryUsage());
                NRMAReadMetaValue(NRMA_getMemorySize());
                NRMAReadMetaValue(NRMA_getDiskSize());
                NRMAReadMetaValue(NRMA_getNetworkConnectivity());
                NRMAReadMetaValue(NRMA_getTempDir());
                NRMAReadMetaValue(NRMA_getModelNumber());
            }
        });
    }

    // The crash handler clears the store at the end of NRMA_writeNRMeta while
    // every other thread is still running.
    dispatch_group_async(group, queue, ^{
        for (NSUInteger i = 0; i < iterations; i++) {
            NRMA__freeMetaData();
        }
    });

    long result = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_SEC)));
    XCTAssertEqual(result, 0, @"Concurrent metadata access timed out (possible deadlock)");

    // Whatever the interleaving was, the store is still usable afterwards.
    NRMA_setAppName("final");
    XCTAssertEqual(strcmp(NRMA_getAppName(), "final"), 0);
}

#pragma mark - Metadata store input handling

// The NULL check used to run after strlen(src), so any nil-derived input -- a nil
// app token, version or name -- dereferenced NULL instead of returning early.
- (void)test_metaDataStore_nullValueLeavesThePreviousValueInPlace
{
    NRMA_setAppToken("token-abc");
    NRMA_setAppToken(NULL);

    const char* stored = NRMA_getAppToken();
    XCTAssertTrue(stored != NULL, @"a NULL update must not clear the field");
    XCTAssertEqual(strcmp(stored, "token-abc"), 0);
}

- (void)test_metaDataStore_oversizedValueIsTruncatedNotOverflowed
{
    NSString* huge = [@"" stringByPaddingToLength:8192 withString:@"abcdefghij" startingAtIndex:0];
    NRMA_setAppName(huge.UTF8String);

    const char* stored = NRMA_getAppName();
    XCTAssertTrue(stored != NULL);

    size_t storedLength = strlen(stored);
    XCTAssertTrue(storedLength > 0, @"an oversized value should still retain its prefix");
    XCTAssertTrue(storedLength < huge.length, @"an oversized value must be truncated");
    XCTAssertEqual(strncmp(stored, huge.UTF8String, storedLength), 0,
                   @"the retained prefix should match the input");
}

- (void)test_metaDataStore_clearMarksEveryFieldUnsetAndLeavesTheStoreUsable
{
    NRMA_setAppName("name");
    NRMA_setAppToken("token");
    NRMA_setSessionId("session");
    NRMA_setTempDir("/tmp/");

    NRMA__freeMetaData();

    XCTAssertTrue(NRMA_getAppName() == NULL);
    XCTAssertTrue(NRMA_getAppToken() == NULL);
    XCTAssertTrue(NRMA_getSessionId() == NULL);
    XCTAssertTrue(NRMA_getTempDir() == NULL);

    NRMA_setAppName("again");
    XCTAssertEqual(strcmp(NRMA_getAppName(), "again"), 0);
}

#pragma mark - Temp file name

// -setUp leaves the temp dir unset. This used to call strlen(NULL).
- (void)test_createTempFileName_returnsNULLWhenTempDirIsUnset
{
    XCTAssertTrue(NRMA_createTempFileName() == NULL);
}

// The previous implementation strncat'd into uninitialized malloc'd memory, so
// the result was whatever garbage preceded the intended path in the block.
- (void)test_createTempFileName_producesTheTempDirPlusTheFileName
{
    NRMA_setTempDir("/tmp/nr-meta-test/");

    const char* path = NRMA_createTempFileName();
    XCTAssertTrue(path != NULL);
    XCTAssertEqual(strcmp(path, "/tmp/nr-meta-test/" kNRMAMetaFileName), 0, @"got \"%s\"", path);
    free((void*)path);
}

- (void)test_createTempFileName_insertsASeparatorWhenTheTempDirHasNone
{
    NRMA_setTempDir("/tmp/nr-meta-test");

    const char* path = NRMA_createTempFileName();
    XCTAssertTrue(path != NULL);
    XCTAssertEqual(strcmp(path, "/tmp/nr-meta-test/" kNRMAMetaFileName), 0, @"got \"%s\"", path);
    free((void*)path);
}

#pragma mark - NRMA_write

// NRMA_write used to return the byte count of its final write() call rather than
// the total, so every caller's `ret != len` check read a split write as a failure
// and stopped emitting the record mid-way.
//
// This pins the contract rather than reproducing a split: a blocking descriptor
// does not short-write (write() sleeps until everything is queued), and the fd
// types that do short-write cannot be driven deterministically from a unit test.
// The path that matters in production is signal interruption, which is live here
// because NRMA_writeNRMeta runs inside the crash handler. The small send buffer
// below at least forces the multi-write() loop to iterate.
- (void)test_writeCharValue_emitsTheWholeRecordAndReportsTheTotalWritten
{
    int fds[2] = {-1, -1};
    XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, fds), 0, @"%s", strerror(errno));

    // Scalars, because a C array cannot be captured by the drain block below.
    const int writeFd = fds[0];
    const int readFd = fds[1];

    int sendBufferSize = 2048;
    setsockopt(writeFd, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, sizeof(sendBufferSize));

    NSString* value = [@"" stringByPaddingToLength:64 * 1024 withString:@"v" startingAtIndex:0];
    NSString* expected = [NSString stringWithFormat:@"appname:%@\n", value];
    NSUInteger expectedLength = expected.length;

    // Drain concurrently: without a reader the send buffer fills and the write
    // blocks forever rather than returning short.
    NSMutableData* received = [NSMutableData data];
    dispatch_semaphore_t drained = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buffer[4096];
        while (received.length < expectedLength) {
            ssize_t got = read(readFd, buffer, sizeof(buffer));
            if (got <= 0) {
                break;
            }
            [received appendBytes:buffer length:(NSUInteger)got];
        }
        dispatch_semaphore_signal(drained);
    });

    // NRMA_write must report the total, which is what every caller compares
    // against; returning the size of the last write() instead is what broke the
    // callers' success check.
    XCTAssertEqual(NRMA_write(writeFd, value.UTF8String, 0), 0,
                   @"a zero-length write is not a failure");

    int result = NRMA_writeCharValue(writeFd, kNRMAMetaKey_AppName, value.UTF8String);
    XCTAssertEqual(result, 0, @"the record must be reported as fully written");

    XCTAssertEqual(dispatch_semaphore_wait(drained, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC))), 0,
                   @"reader did not finish draining");

    close(writeFd);
    close(readFd);

    NSString* actual = [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(actual, expected, @"the record, including its trailing newline, must arrive intact");
}

#pragma mark - Interaction history

- (void)test_interactionHistory_retainsTheMostRecentEntriesNewestFirst
{
    const int overflowBy = 10;
    const int total = NRMA_INTERACTION_HISTORY_CAPACITY + overflowBy;

    for (int i = 1; i <= total; i++) {
        NRMA__AddInteraction([NSString stringWithFormat:@"trace-%d", i].UTF8String, (long long)i * 100);
    }

    NRMAInteractionHistorySnapshot snapshot = NRMA__snapshotInteractionHistory();
    XCTAssertEqual(snapshot.count, (uint32_t)NRMA_INTERACTION_HISTORY_CAPACITY,
                   @"the ring must stay bounded at its capacity");

    for (uint32_t index = 0; index < snapshot.count; index++) {
        char name[NRMA_INTERACTION_NAME_CAPACITY + 1] = {0};
        long long timestampMillis = 0;
        XCTAssertTrue(NRMA__readInteraction(snapshot, index, name, sizeof(name), &timestampMillis),
                      @"entry %u should be readable", index);

        int expected = total - (int)index;
        XCTAssertEqual(strcmp(name, [NSString stringWithFormat:@"trace-%d", expected].UTF8String), 0,
                       @"entry %u: got \"%s\"", index, name);
        XCTAssertEqual(timestampMillis, (long long)expected * 100);
    }

    // Reading past the snapshot fails instead of walking off the ring.
    char overflow[8] = {0};
    XCTAssertFalse(NRMA__readInteraction(snapshot, snapshot.count, overflow, sizeof(overflow), NULL));
}

- (void)test_interactionHistory_ignoresNullAndEmptyNamesAndTruncatesLongOnes
{
    NRMA__AddInteraction(NULL, 1);
    NRMA__AddInteraction("", 2);
    XCTAssertEqual(NRMA__snapshotInteractionHistory().count, 0u);

    NSString* huge = [@"" stringByPaddingToLength:4096 withString:@"x" startingAtIndex:0];
    NRMA__AddInteraction(huge.UTF8String, 3);

    NRMAInteractionHistorySnapshot snapshot = NRMA__snapshotInteractionHistory();
    XCTAssertEqual(snapshot.count, 1u);

    char name[NRMA_INTERACTION_NAME_CAPACITY + 1] = {0};
    XCTAssertTrue(NRMA__readInteraction(snapshot, 0, name, sizeof(name), NULL));
    XCTAssertEqual(strlen(name), (size_t)NRMA_INTERACTION_NAME_CAPACITY);
}

// The previous linked list was walked and free()'d with no synchronization, so a
// reader could follow a node another thread had already released.
- (void)test_interactionHistory_concurrentInsertsReadsAndClearsAreSafe
{
    const NSUInteger iterations = 5000;

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSUInteger w = 0; w < 4; w++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger i = 0; i < iterations; i++) {
                @autoreleasepool {
                    NSString* name = [NSString stringWithFormat:@"w%lu-%lu",
                                      (unsigned long)w, (unsigned long)i];
                    NRMA__AddInteraction(name.UTF8String, (long long)i);
                }
            }
        });
    }

    dispatch_group_async(group, queue, ^{
        for (NSUInteger i = 0; i < iterations; i++) {
            NRMAInteractionHistorySnapshot snapshot = NRMA__snapshotInteractionHistory();
            for (uint32_t index = 0; index < snapshot.count; index++) {
                char name[NRMA_INTERACTION_NAME_CAPACITY + 1];
                long long timestampMillis = 0;
                if (NRMA__readInteraction(snapshot, index, name, sizeof(name), &timestampMillis)) {
                    NRMAReadMetaValue(name);
                }
            }
        }
    });

    dispatch_group_async(group, queue, ^{
        for (NSUInteger i = 0; i < iterations / 10; i++) {
            NRMA__clearInteractionHistory();
        }
    });

    long result = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_SEC)));
    XCTAssertEqual(result, 0, @"Concurrent interaction history access timed out (possible deadlock)");

    NRMA__clearInteractionHistory();
    NRMA__AddInteraction("after", 42);
    XCTAssertEqual(NRMA__snapshotInteractionHistory().count, 1u);
}

@end
