//
//  NRMAOfflineStorageTests.m
//  Agent
//
//  Created by Mike Bruin on 1/5/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAOfflineStorage.h"
#import "NRMAFakeDataHelper.h"

@interface NRMAOfflineStorageTests : XCTestCase
@property(strong) NRMAOfflineStorage* offlineStorage;

@end

@implementation NRMAOfflineStorageTests

-(void) setUp {
    [super setUp];
    self.offlineStorage = [[NRMAOfflineStorage alloc] initWithEndpoint:@"Test"];
    [self.offlineStorage clearAllOfflineFiles];
}

-(void) tearDown {
    [super tearDown];
    [self.offlineStorage clearAllOfflineFiles];
}

- (unsigned long long)folderSize:(NSString *)folderPath {
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:folderPath error:nil];
    NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
    NSString *fileName;
    unsigned long long fileSize = 0;

    while (fileName = [filesEnumerator nextObject]) {
        NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[folderPath stringByAppendingPathComponent:fileName] error:Nil];
        fileSize += [fileDictionary fileSize];
    }

    return fileSize;
}

-(void) testOfflineStorage {
    [self.offlineStorage setMaxOfflineStorageSize:100];
    NSData *data = [NRMAFakeDataHelper makeDataDictionary:1000];
    
    XCTAssertTrue([self.offlineStorage persistDataToDisk:data]);

    // Size is now derived from what's actually on disk rather than a cached counter.
    unsigned long long acutalSavedSize = [self folderSize:[_offlineStorage offlineDirectoryPath]];
    XCTAssertTrue(acutalSavedSize == data.length);

    NSArray<NSData *> *savedData = [self.offlineStorage getAllOfflineData:TRUE];
    
    XCTAssertEqualObjects(data, savedData[0]);
}

// Regression test for same-second filename collisions: the replay loop in sendOfflineStorage
// re-persists every buffered payload back-to-back while the device is still offline, so several
// persists land within the same wall-clock second. With a second-resolution filename those
// writes overwrote each other and silently dropped all but the last payload. Each persist must
// now produce its own file.
-(void) testRapidPersistsDoNotOverwriteEachOther {
    [self.offlineStorage setMaxOfflineStorageSize:100]; // plenty of headroom, no eviction

    NSUInteger persistCount = 5;
    NSUInteger expectedTotalSize = 0;
    for (NSUInteger i = 0; i < persistCount; i++) {
        NSData *data = [NRMAFakeDataHelper makeDataDictionary:100 + i]; // distinct payloads
        XCTAssertTrue([self.offlineStorage persistDataToDisk:data]);
        expectedTotalSize += data.length;
    }

    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[_offlineStorage offlineDirectoryPath] error:nil];
    XCTAssertEqual(files.count, persistCount, @"Each rapid persist should create its own file rather than overwrite the previous one");

    unsigned long long savedSize = [self folderSize:[_offlineStorage offlineDirectoryPath]];
    XCTAssertEqual(savedSize, expectedTotalSize, @"On-disk size should account for every persisted payload");

    NSArray<NSData *> *savedData = [self.offlineStorage getAllOfflineData:TRUE];
    XCTAssertEqual(savedData.count, persistCount, @"All buffered payloads should be recoverable for replay");
}

-(void) testClearAllOfflineStorage {
    [self.offlineStorage setMaxOfflineStorageSize:100];
    NSData *data = [NRMAFakeDataHelper makeDataDictionary:1000];
    
    XCTAssertTrue([self.offlineStorage persistDataToDisk:data]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[NRMAOfflineStorage allOfflineDirectorysPath] isDirectory:nil]);
    
    XCTAssertTrue([NRMAOfflineStorage clearAllOfflineDirectories]);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[NRMAOfflineStorage allOfflineDirectorysPath] isDirectory:nil]);
}


@end
