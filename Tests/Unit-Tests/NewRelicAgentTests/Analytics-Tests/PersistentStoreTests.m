//
//  PersistentStoreTests.m
//  Agent_Tests
//
//  Created by Steve Malsam on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "PersistentStore.h"
#import "NRMAMobileEvent.h"

@interface TestEvent : NRMAMobileEvent <NSCoding>
- (instancetype) initWithTimestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
            withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator;
@end

@implementation TestEvent
- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator {
    self = [super initWithTimestamp:timestamp
        sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds
             withAttributeValidator:attributeValidator];
    if (self) {

    }
    
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeDouble:self.timestamp forKey:@"Timestamp"];
    [coder encodeDouble:self.sessionElapsedTimeSeconds forKey:@"SessionElapsedTimeInSeconds"];
    [coder encodeObject:self.eventType forKey:@"EventType"];
    [coder encodeObject:self.attributes forKey:@"Attributes"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super init];
    if(self) {
        self.timestamp = [coder decodeDoubleForKey:@"Timestamp"];
        self.sessionElapsedTimeSeconds = [coder decodeDoubleForKey:@"SessionElapsedTimeInSeconds"];
        self.eventType = [coder decodeObjectForKey:@"EventType"];
        self.attributes = [coder decodeObjectForKey:@"Attributes"];
    }
    
    return self;
}

@end

@interface PersistentStoreTests : XCTestCase

@end

@implementation PersistentStoreTests
    NSString *testFilename = @"fbstest_tempStore";

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

//- (void)testExample {
//    // This is an example of a functional test case.
//    // Use XCTAssert and related functions to verify your tests produce the correct results.
//}
//
//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

- (void)testStoresObject {
    // Given
    PersistentStore<NSString *, TestEvent*> *sut = [PersistentStore new];
    
    TestEvent *testEvent = [[TestEvent alloc] initWithTimestamp:10
                                            sessionElapsedTimeInSeconds:50
                                                 withAttributeValidator:nil];
    
    // When
    [sut setObject:testEvent forKey:@"aKey"];
    
    // Then
    TestEvent *retrievedEvent = [sut objectForKey:@"aKey"];
    XCTAssertEqual(testEvent, retrievedEvent);
}

- (void)testWritesObjectToFile {
    // Given
    PersistentStore *sut = [[PersistentStore alloc] initWithFilename:testFilename
                                                     andMinimumDelay:1];

    TestEvent *testEvent = [[TestEvent alloc] initWithTimestamp:10
                                            sessionElapsedTimeInSeconds:50
                                                 withAttributeValidator:nil];
    
    [testEvent addAttribute:@"AnAttribute" value:@1];
    [testEvent addAttribute:@"AnotherAttribute" value:@NO];
    [testEvent addAttribute:@"AThirdAttribute" value:@"Attribute"];

    // When
    [sut setObject:testEvent forKey:@"aKey"];


    // Then
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    XCTAssertTrue([fileManager fileExistsAtPath:testFilename]);
    
    NSData *retrievedData = [NSData dataWithContentsOfFile:testFilename];
    NSError *error = nil;
    NSMutableDictionary *retrievedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:retrievedData
                                                                                            error:&error];
    XCTAssertNil(error, "Error testing file written: %@", [error localizedDescription]);
    XCTAssertEqual([retrievedDictionary count], 1);
    
    PersistentStore *anotherOne = [[PersistentStore alloc] initWithFilename:testFilename
                                                            andMinimumDelay:1];
    [anotherOne load:&error];
    XCTAssertNil(error, "Error loading previous events: %@", [error localizedDescription]);
    TestEvent *anotherEvent = [anotherOne objectForKey:@"aKey"];
    XCTAssertNotNil(anotherEvent);
    XCTAssertEqual(anotherEvent.timestamp, testEvent.timestamp);
    XCTAssertEqual(anotherEvent.sessionElapsedTimeSeconds, testEvent.sessionElapsedTimeSeconds);
    XCTAssertEqual([anotherEvent.attributes count], [testEvent.attributes count]);
}

- (void)testStoreReturnsNoIfFileDoesNotExist {
    PersistentStore *sut = [[PersistentStore alloc] initWithFilename:@"FileDoesNotExist"
                                                     andMinimumDelay:1];
    NSError *error = nil;
    XCTAssertFalse([sut load:&error]);
}

@end
