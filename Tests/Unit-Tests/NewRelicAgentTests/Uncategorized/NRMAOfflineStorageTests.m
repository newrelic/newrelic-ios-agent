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

-(void) testClearAllOfflineStorage {
    [self.offlineStorage setMaxOfflineStorageSize:100];
    NSData *data = [NRMAFakeDataHelper makeDataDictionary:1000];
    
    XCTAssertTrue([self.offlineStorage persistDataToDisk:data]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[NRMAOfflineStorage allOfflineDirectorysPath] isDirectory:nil]);
    
    XCTAssertTrue([NRMAOfflineStorage clearAllOfflineDirectories]);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[NRMAOfflineStorage allOfflineDirectorysPath] isDirectory:nil]);
}


@end
