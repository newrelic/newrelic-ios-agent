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
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"com.newrelic.offlineStorageCurrentSize"];
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
    NSData *data = [NRMAFakeDataHelper makeDataDictionary:1000];
    
    XCTAssertTrue([self.offlineStorage persistDataToDisk:data]);
    NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.newrelic.offlineStorageCurrentSize"];
    XCTAssertTrue(currentOfflineStorageSize == data.length);
    
    unsigned long long acutalSavedSize = [self folderSize:[_offlineStorage offlineDirectoryPath]];
    XCTAssertTrue(acutalSavedSize == data.length);

    NSArray<NSData *> *savedData = [self.offlineStorage getAllOfflineData:TRUE];
    
    XCTAssertEqualObjects(data, savedData[0]);
}

-(void) testMaxOfflineStorageSize {
    [self.offlineStorage setMaxOfflineStorageSize:1];
    NSData *data = [NRMAFakeDataHelper makeDataDictionary:5000];
    
    int count = 0;
    while([self.offlineStorage persistDataToDisk:data]){
        count++;
        sleep(1);
    }
    XCTAssertFalse([self.offlineStorage persistDataToDisk:data]);
    
    NSUInteger currentOfflineStorageSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.newrelic.offlineStorageCurrentSize"];
    unsigned long long acutalSavedSize = [self folderSize:[_offlineStorage offlineDirectoryPath]];
    XCTAssertTrue(acutalSavedSize == currentOfflineStorageSize);
    
    NSArray<NSData *> *savedData = [self.offlineStorage getAllOfflineData:TRUE];
    XCTAssertTrue(count == savedData.count);
}


@end
