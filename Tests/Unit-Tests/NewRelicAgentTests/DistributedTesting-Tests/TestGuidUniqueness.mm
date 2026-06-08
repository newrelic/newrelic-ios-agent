//
//  TestGuidUniqueness.mm
//  Agent_Tests
//
//  Regression coverage for NR-516417 / NR-XXXXXX (mCDP cross-region span ID
//  collisions). The previous IGuidGenerator reseeded a default_random_engine
//  with a 32-bit-truncated wall-clock value on every call, so two devices that
//  hit the generator in the same clock tick produced identical trace and span
//  IDs. These tests assert that high-volume single-threaded and concurrent use
//  of the production payload-generation path does not produce duplicates.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <vector>

#include <Connectivity/Facade.hpp>
#include <Utilities/Application.hpp>
#include <Utilities/ApplicationContext.hpp>

@interface TestGuidUniqueness : XCTestCase
@end

@implementation TestGuidUniqueness

- (void)setUp {
    NewRelic::Application::getInstance().setContext(
        NewRelic::ApplicationContext("accountId", "applicationId", "1"));
}

- (void)tearDown {
    NewRelic::Application::getInstance().setContext(
        NewRelic::ApplicationContext("", "", ""));
}

- (void)testFacadeNewPayloadTightLoopProducesNoDuplicates {
    // newPayload is the cheapest production code path (one generateGuid call,
    // no trace-id regeneration, no string formatting beyond the 16-char id).
    // Tight loop maximises same-clock-tick density to surface the LCG bug.
    NewRelic::Application::getInstance().setContext(
        NewRelic::ApplicationContext("accountId", "applicationId", "1"));
    (void)NewRelic::Connectivity::Facade::getInstance().startTrip();   // seed _currentTraceId

    const NSUInteger iterations = 100000;
    NSMutableSet<NSString*> *seen = [NSMutableSet setWithCapacity:iterations];
    NSUInteger duplicates = 0;
    NSString *firstDup = nil;
    NSUInteger firstDupIter = 0;

    for (NSUInteger i = 0; i < iterations; i++) {
        auto payload = NewRelic::Connectivity::Facade::getInstance().newPayload();
        if (!payload) continue;
        NSString *spanId = @(payload->getId().c_str());
        if ([seen containsObject:spanId]) {
            if (duplicates == 0) { firstDup = spanId; firstDupIter = i; }
            duplicates++;
        } else {
            [seen addObject:spanId];
        }
    }

    XCTAssertEqual(duplicates, 0u,
                   @"%lu duplicate span IDs across %lu newPayload calls; first was %@ at iter %lu",
                   (unsigned long)duplicates, (unsigned long)iterations,
                   firstDup, (unsigned long)firstDupIter);
}

- (void)testFacadeNewPayloadTightLoopUnderConcurrencyProducesNoDuplicates {
    NewRelic::Application::getInstance().setContext(
        NewRelic::ApplicationContext("accountId", "applicationId", "1"));
    (void)NewRelic::Connectivity::Facade::getInstance().startTrip();

    const NSUInteger threadCount = 64;
    const NSUInteger perThread   = 5000;

    NSLock *lock = [[NSLock alloc] init];
    NSMutableSet<NSString*> *seen = [NSMutableSet setWithCapacity:threadCount * perThread];
    __block NSUInteger duplicates = 0;

    dispatch_apply(threadCount, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t) {
        @autoreleasepool {
            std::vector<std::string> local;
            local.reserve(perThread);
            for (NSUInteger i = 0; i < perThread; i++) {
                auto payload = NewRelic::Connectivity::Facade::getInstance().newPayload();
                if (payload) local.push_back(payload->getId());
            }

            [lock lock];
            for (auto& s : local) {
                NSString *n = @(s.c_str());
                if ([seen containsObject:n]) duplicates++;
                else [seen addObject:n];
            }
            [lock unlock];
        }
    });

    XCTAssertEqual(duplicates, 0u,
                   @"%lu duplicate span IDs across %lu concurrent newPayload calls",
                   (unsigned long)duplicates,
                   (unsigned long)(threadCount * perThread));
}

- (void)testFacadeStartTripProducesUniqueIdsAtVolume {
    const NSUInteger iterations = 20000;
    NSMutableSet<NSString*> *traceIds = [NSMutableSet setWithCapacity:iterations];
    NSMutableSet<NSString*> *spanIds  = [NSMutableSet setWithCapacity:iterations];
    NSUInteger traceDupes = 0;
    NSUInteger spanDupes  = 0;

    for (NSUInteger i = 0; i < iterations; i++) {
        auto payload = NewRelic::Connectivity::Facade::getInstance().startTrip();
        XCTAssertTrue(payload != nullptr);
        NSString *traceId = @(payload->getTraceId().c_str());
        NSString *spanId  = @(payload->getId().c_str());

        XCTAssertEqual(traceId.length, 32u, @"trace id must be 32 hex chars");
        XCTAssertEqual(spanId.length,  16u, @"span id must be 16 hex chars");

        if ([traceIds containsObject:traceId]) traceDupes++; else [traceIds addObject:traceId];
        if ([spanIds containsObject:spanId])   spanDupes++;  else [spanIds addObject:spanId];
    }
    XCTAssertEqual(traceDupes, 0u, @"%lu trace-id duplicates across %lu startTrip calls", (unsigned long)traceDupes, (unsigned long)iterations);
    XCTAssertEqual(spanDupes,  0u, @"%lu span-id duplicates across %lu startTrip calls",  (unsigned long)spanDupes,  (unsigned long)iterations);
}

- (void)testGeneratePayloadProducesUniqueIdsUnderConcurrency {
    NewRelic::Application::getInstance().setContext(
        NewRelic::ApplicationContext("accountId", "applicationId", "1"));

    const NSUInteger threadCount = 32;
    const NSUInteger perThread   = 2000;

    NSLock *lock = [[NSLock alloc] init];
    NSMutableSet<NSString*> *traceIds = [NSMutableSet setWithCapacity:threadCount * perThread];
    NSMutableSet<NSString*> *spanIds  = [NSMutableSet setWithCapacity:threadCount * perThread];
    __block NSUInteger traceCollisions = 0;
    __block NSUInteger spanCollisions  = 0;
    __block NSUInteger nullPayloads    = 0;

    dispatch_apply(threadCount, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t) {
        @autoreleasepool {
            NSMutableArray<NSString*> *localTrace = [NSMutableArray arrayWithCapacity:perThread];
            NSMutableArray<NSString*> *localSpan  = [NSMutableArray arrayWithCapacity:perThread];

            for (NSUInteger i = 0; i < perThread; i++) {
                auto payload = NewRelic::Connectivity::Facade::getInstance().startTrip();
                if (payload == nullptr) {
                    nullPayloads++;
                    continue;
                }
                [localTrace addObject:@(payload->getTraceId().c_str())];
                [localSpan  addObject:@(payload->getId().c_str())];
            }

            [lock lock];
            for (NSString *t in localTrace) {
                if ([traceIds containsObject:t]) traceCollisions++;
                else [traceIds addObject:t];
            }
            for (NSString *s in localSpan) {
                if ([spanIds containsObject:s]) spanCollisions++;
                else [spanIds addObject:s];
            }
            [lock unlock];
        }
    });

    XCTAssertEqual(nullPayloads, 0u, @"Facade::startTrip returned nullptr %lu times — Application context lost?", (unsigned long)nullPayloads);
    XCTAssertEqual(traceCollisions, 0u,
                   @"trace id collisions across %lu concurrent generators",
                   (unsigned long)(threadCount * perThread));
    XCTAssertEqual(spanCollisions, 0u,
                   @"span id collisions across %lu concurrent generators",
                   (unsigned long)(threadCount * perThread));
}

- (void)testGeneratedIdsAreLowercaseHex {
    auto payload = NewRelic::Connectivity::Facade::getInstance().startTrip();
    XCTAssertTrue(payload != nullptr);
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    NSString *traceId = @(payload->getTraceId().c_str());
    NSString *spanId  = @(payload->getId().c_str());
    for (NSUInteger i = 0; i < traceId.length; i++) {
        XCTAssertTrue([allowed characterIsMember:[traceId characterAtIndex:i]],
                      @"non-hex char in trace id %@", traceId);
    }
    for (NSUInteger i = 0; i < spanId.length; i++) {
        XCTAssertTrue([allowed characterIsMember:[spanId characterAtIndex:i]],
                      @"non-hex char in span id %@", spanId);
    }
}

@end
