//
//  TestIntegratedEventManager.m
//  Agent_Tests
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMAEventManager.h"

#import "NRMACustomEvent.h"
#import "BlockAttributeValidator.h"
#import "NRMAFlags.h"

@interface TestIntegratedEventManager : XCTestCase {
    NRMAEventManager *sut;
    BlockAttributeValidator *agreeableAttributeValidator;
}
@end

@interface DropAllEventManager : NRMAEventManager
@end
@implementation DropAllEventManager
- (NSUInteger)getEvictionIndex {
    return 9999; // always out of bounds -> forces the "drop incoming event" path
}
@end

@implementation TestIntegratedEventManager

    static NSString *testFilename = @"fbstest_tempStore";

- (void)setUp {
    
    [NRMAFlags enableFeatures:NRFeatureFlag_NewEventSystem];

    // Put setup code here. This method is called before the invocation of each test method in the class.
    sut = [[NRMAEventManager alloc] initWithPersistentStore:[[PersistentEventStore alloc] initWithFilename:testFilename
                                                                                           andMinimumDelay:1]];
    
    if(agreeableAttributeValidator == nil) {
        agreeableAttributeValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
            return YES;
        } valueValidator:^BOOL(id value) {
            return YES;
        } andEventTypeValidator:^BOOL(NSString *eventType) {
            return YES;
        }];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
}

- (void)testRetrieveEventJSON {
    // Given
    NSTimeInterval timestamp = 10;
    unsigned long long elapsedTime = 50;
//    NRMAAnalyticEvent *testEvent = [[NRMAAnalyticEvent alloc] initWithTimestamp:timestamp
    NRMACustomEvent *testEvent = [[NRMACustomEvent alloc] initWithEventType:@"CustomEvent"
                                                                  timestamp:timestamp
                                                sessionElapsedTimeInSeconds:elapsedTime
                                                     withAttributeValidator:agreeableAttributeValidator];
    NSError *error = nil;
    
    // When
    [sut addEvent:testEvent];
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error clearEvents:true];
    
    // Then
    XCTAssertNotNil(eventJSONString, "Event JSON String not properly created");
    
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertNotNil(decode[0][@"timestamp"]);
    double retrievedTimestamp = [decode[0][@"timestamp"] doubleValue];
    XCTAssertEqual(retrievedTimestamp, timestamp);
    XCTAssertNotNil(decode[0][@"timeSinceLoad"]);
    unsigned long long retrievedElapsedTime = [decode[0][@"timeSinceLoad"] unsignedLongLongValue];
    XCTAssertEqual(retrievedElapsedTime, elapsedTime);
}

- (void)testMaxBufferSize {
    // Given
    [sut setMaxEventBufferSize:1];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEevntTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:5
                                                     sessionElapsedTimeInSeconds:15
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    // When
    [sut addEvent:customEventOne];
    [sut addEvent:customEevntTwo];
    
    // Then
    NSError *error = nil;
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error clearEvents:true];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(decode.count, 1);
}

- (void)testZeroMaxBufferSize {
    [sut setMaxEventBufferSize:0];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    [sut addEvent:customEventOne];
    
    NSError *error = nil;
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error clearEvents:true];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(decode.count, 0);
}

- (void)testNotAgedOutEvents {
    // Given
    [sut setMaxEventBufferTimeInSeconds:NSUIntegerMax];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    // When
    [sut addEvent:customEventOne];
    
    // Then
    XCTAssertFalse([sut didReachMaxQueueTime:[[NSDate now] timeIntervalSince1970]]);
}

- (void)testAgedOutEvents {
    // Given
    [sut setMaxEventBufferTimeInSeconds:1];
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    // When
    [sut addEvent:customEventOne];
    
    // Then
    XCTAssertTrue([sut didReachMaxQueueTime:[[NSDate now] timeIntervalSince1970]]);
}

- (void)testEmptyEvents {
    // Given
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventThree = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 3"
                                                                       timestamp:3
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    [sut addEvent:customEventOne];
    [sut addEvent:customEventTwo];
    [sut addEvent:customEventThree];

    NSError *error = nil;
    NSString *eventJSONString = [sut getEventJSONStringWithError:&error clearEvents:true];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    
    XCTAssertEqual(decode.count, 3);
    
    
    [sut empty];
    
    NSString *emptyJSONString = [sut getEventJSONStringWithError:&error clearEvents:true];
    NSArray *emptyDecode = [NSJSONSerialization JSONObjectWithData:[emptyJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(emptyDecode.count, 0);
}

- (void)testEmptyEventsDoesNotResetOldestEventTime {
    // Given
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];

    NRMACustomEvent *customEventTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];

    NRMACustomEvent *customEventThree = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 3"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    [sut setMaxEventBufferTimeInSeconds:1];

    [sut addEvent:customEventOne];
    [sut addEvent:customEventTwo];
    [sut addEvent:customEventThree];

    XCTAssertTrue([sut didReachMaxQueueTime:2000]);

    // When - empty() is called (during normal harvest)
    [sut empty];

    // Then - timestamp should persist (matching Android behavior)
    XCTAssertTrue([sut didReachMaxQueueTime:2000]);
}

- (void)testResetTimestampResetsOldestEventTime {
    // Given
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];

    NRMACustomEvent *customEventTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];

    NRMACustomEvent *customEventThree = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 3"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    [sut setMaxEventBufferTimeInSeconds:1];

    [sut addEvent:customEventOne];
    [sut addEvent:customEventTwo];
    [sut addEvent:customEventThree];

    XCTAssertTrue([sut didReachMaxQueueTime:2000]);

    // When - resetTimestamp() is explicitly called (during session clear)
    [sut resetTimestamp];

    // Then - timestamp should be reset
    XCTAssertFalse([sut didReachMaxQueueTime:2000]);
}

-(void)testGettingEventJSONClearsEvents {
    // Given
    NRMACustomEvent *customEventOne = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventTwo = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    NRMACustomEvent *customEventThree = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 3"
                                                                       timestamp:1000
                                                     sessionElapsedTimeInSeconds:20
                                                          withAttributeValidator:agreeableAttributeValidator];
    
    [sut addEvent:customEventOne];
    [sut addEvent:customEventTwo];
    [sut addEvent:customEventThree];
    
    // When
    NSError *error = nil;
    NSString *firstJSONEvents = [sut getEventJSONStringWithError:&error clearEvents:YES];
    
    // Then
    NSString *secondJSONEvents = [sut getEventJSONStringWithError:&error clearEvents:YES];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[secondJSONEvents dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:nil];
    XCTAssertEqual(decode.count, 0);
}

- (void)testAddEventIncrementsRecordedCount {
    NRMACustomEvent *event = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                timestamp:3
                                              sessionElapsedTimeInSeconds:20
                                                   withAttributeValidator:agreeableAttributeValidator];
    BOOL added = [sut addEvent:event];

    XCTAssertTrue(added);
    XCTAssertEqual([sut getEventsRecordedCount], 1);
    XCTAssertEqual([sut getEventsEvictedCount], 0);
}

- (void)testOverflowEvictsAndIncrementsEvictedCount {
    [sut setMaxEventBufferSize:1];
    NRMACustomEvent *first = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                               timestamp:3
                                             sessionElapsedTimeInSeconds:20
                                                  withAttributeValidator:agreeableAttributeValidator];
    NRMACustomEvent *second = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                timestamp:5
                                              sessionElapsedTimeInSeconds:15
                                                   withAttributeValidator:agreeableAttributeValidator];

    XCTAssertTrue([sut addEvent:first]);
    // Deterministic: after 1 attempted insert, getEvictionIndex() == arc4random() % 1 == 0,
    // which evicts the only resident event and admits the new one.
    XCTAssertTrue([sut addEvent:second]);

    XCTAssertEqual([sut getEventsRecordedCount], 2);
    XCTAssertEqual([sut getEventsEvictedCount], 1);
}

- (void)testOutOfBoundsEvictionIndexDropsIncomingEventInstead {
    DropAllEventManager *dropSut = [[DropAllEventManager alloc] initWithPersistentStore:[[PersistentEventStore alloc] initWithFilename:@"fbstest_dropall"
                                                                                                                        andMinimumDelay:1]];
    [dropSut setMaxEventBufferSize:1];
    NRMACustomEvent *first = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                               timestamp:3
                                             sessionElapsedTimeInSeconds:20
                                                  withAttributeValidator:agreeableAttributeValidator];
    NRMACustomEvent *second = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 2"
                                                                timestamp:5
                                              sessionElapsedTimeInSeconds:15
                                                   withAttributeValidator:agreeableAttributeValidator];

    XCTAssertTrue([dropSut addEvent:first]);
    XCTAssertFalse([dropSut addEvent:second], @"Second event should be dropped, not silently accepted.");

    NSError *error = nil;
    NSString *eventJSONString = [dropSut getEventJSONStringWithError:&error clearEvents:false];
    NSArray *decode = [NSJSONSerialization JSONObjectWithData:[eventJSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                        options:0
                                                          error:nil];
    XCTAssertEqual(decode.count, 1, @"Only the first event should remain in the queue.");

    XCTAssertEqual([dropSut getEventsRecordedCount], 1);
    XCTAssertEqual([dropSut getEventsEvictedCount], 1);
}

- (void)testUnconfirmedHarvestAttemptLeavesPersistedEventsIntact {
    // A force-quit between an *attempted* harvest and -confirmEventsSent must
    // not lose data: the on-disk backup has to survive until delivery is
    // actually confirmed, not merely attempted.
    NSString *filename = @"fbstest_confirmEventsSent";
    [[NSFileManager defaultManager] removeItemAtPath:filename error:nil];

    PersistentEventStore *persistentStore = [[PersistentEventStore alloc] initWithFilename:filename
                                                                             andMinimumDelay:.025];
    NRMAEventManager *manager = [[NRMAEventManager alloc] initWithPersistentStore:persistentStore];

    NRMACustomEvent *event = [[NRMACustomEvent alloc] initWithEventType:@"Custom Event 1"
                                                                timestamp:3
                                              sessionElapsedTimeInSeconds:20
                                                   withAttributeValidator:agreeableAttributeValidator];
    [manager addEvent:event];

    // Wait for the add's debounced save to actually land on disk.
    NSPredicate *addedPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        return [PersistentEventStore getLastSessionEventsFromFilename:filename].count == 1;
    }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:addedPredicate object:nil]] timeout:5];

    // When: the event is pulled out for a harvest attempt, but not confirmed sent.
    NSError *error = nil;
    NSString *json = [manager getEventJSONStringWithError:&error clearEvents:YES];
    XCTAssertNotNil(json);

    // Then: a simulated force-quit here must still find it recoverable on disk.
    XCTAssertEqual([PersistentEventStore getLastSessionEventsFromFilename:filename].count, 1,
                    @"an unconfirmed harvest attempt must not clear the persistent backup");

    // The in-memory buffer must still have rotated, though, so the next batch
    // doesn't re-send what's already pending confirmation.
    NSString *secondJson = [manager getEventJSONStringWithError:&error clearEvents:YES];
    NSArray *secondDecode = [NSJSONSerialization JSONObjectWithData:[secondJson dataUsingEncoding:NSUTF8StringEncoding]
                                                              options:0
                                                                error:nil];
    XCTAssertEqual(secondDecode.count, 0);

    // When: delivery is confirmed.
    [manager confirmEventsSent];

    // Then: only now does the persistent backup drop the confirmed batch.
    NSPredicate *clearedPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        return [PersistentEventStore getLastSessionEventsFromFilename:filename].count == 0;
    }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:clearedPredicate object:nil]] timeout:5];

    [[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
}

@end
