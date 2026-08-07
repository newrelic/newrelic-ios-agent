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

@interface NRMAExceptionMetaDataTest : XCTestCase

@end

@implementation NRMAExceptionMetaDataTest

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
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

// Repro for the __NRMA_assign_retain NULL-check-after-use bug: strlen(src) was called
// before the NULL check, so any nil-derived input (e.g. a nil app token/version/name)
// crashed with EXC_BAD_ACCESS in strlen instead of returning early.
- (void)test_NRMA_assign_retain_crashesOnNullSrc
{
    NRMA_setAppToken(NULL);
}

@end
