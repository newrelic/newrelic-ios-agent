//
//  NRMANSCacheInstrumentationTests.m
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "NRMANSCacheInstrumentation.h"
#import "NRMAMethodSwizzling.h"

// Exposed override functions so we can verify the swizzle landed.
extern id   NRMAOverride__objectForKey(NSCache *self, SEL _cmd, id key);
extern void NRMAOverride__setObjectForKey(NSCache *self, SEL _cmd, id obj, id key);
extern void NRMAOverride__setObjectForKeyCost(NSCache *self, SEL _cmd, id obj, id key, NSUInteger cost);

@interface NRMANSCacheInstrumentationTests : XCTestCase
@end

@implementation NRMANSCacheInstrumentationTests

- (void)setUp {
    [super setUp];
    [NRMANSCacheInstrumentation beginInstrumentation];
    [NRMANSCacheInstrumentation clearRecordedEvents];
}

- (void)tearDown {
    [NRMANSCacheInstrumentation clearRecordedEvents];
    [super tearDown];
}

// ---------------------------------------------------------------------------
#pragma mark - Swizzle installation
// ---------------------------------------------------------------------------

- (void)testSwizzlesAreInstalled {
    Class cacheClass = [NSCache class];
    Dl_info info;

    IMP imp = class_getMethodImplementation(cacheClass, @selector(objectForKey:));
    dladdr(imp, &info);
    XCTAssertEqual(imp, (IMP)NRMAOverride__objectForKey,
                   @"-objectForKey: should be swizzled to NRMAOverride__objectForKey (got %s)", info.dli_sname);

    imp = class_getMethodImplementation(cacheClass, @selector(setObject:forKey:));
    dladdr(imp, &info);
    XCTAssertEqual(imp, (IMP)NRMAOverride__setObjectForKey,
                   @"-setObject:forKey: should be swizzled (got %s)", info.dli_sname);

    imp = class_getMethodImplementation(cacheClass, @selector(setObject:forKey:cost:));
    dladdr(imp, &info);
    XCTAssertEqual(imp, (IMP)NRMAOverride__setObjectForKeyCost,
                   @"-setObject:forKey:cost: should be swizzled (got %s)", info.dli_sname);
}

//// ---------------------------------------------------------------------------
//#pragma mark - Store events
//// ---------------------------------------------------------------------------
//
//- (void)testSetObjectRecordsStoreEvent {
//    NSCache *cache = [NSCache new];
//    NSURL *url = [NSURL URLWithString:@"https://example.com/image.png"];
//
//    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
//        return (NSURL *)key;   // key IS the URL in this test
//    }];
//
//    [cache setObject:@"value" forKey:url];
//
//    // Give the barrier write a moment to land.
//    [self drainEventLog];
//
//    XCTAssertEqual([NRMANSCacheInstrumentation storeCount], 1u,
//                   @"One store event expected after -setObject:forKey:");
//    XCTAssertEqual([NRMANSCacheInstrumentation hitCount],   0u);
//    XCTAssertEqual([NRMANSCacheInstrumentation missCount],  0u);
//
//    NRMACacheEvent *event = [NRMANSCacheInstrumentation recordedEvents].firstObject;
//    XCTAssertEqualObjects(event[@"url"],       url.absoluteString);
//    XCTAssertEqualObjects(event[@"cacheType"], @"NSCache");
//    XCTAssertEqualObjects(event[@"stored"],    @YES);
//    XCTAssertNil(event[@"hit"], @"Store events must not carry a 'hit' key");
//}

- (void)testSetObjectForKeyCostRecordsStoreEvent {
    NSCache *cache = [NSCache new];
    NSURL *url = [NSURL URLWithString:@"https://example.com/asset.jpg"];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return (NSURL *)key;
    }];

    [cache setObject:@"value" forKey:url cost:42];
    [self drainEventLog];

    XCTAssertEqual([NRMANSCacheInstrumentation storeCount], 1u,
                   @"One store event expected after -setObject:forKey:cost:");
}

// ---------------------------------------------------------------------------
#pragma mark - Lookup events
// ---------------------------------------------------------------------------

- (void)testObjectForKeyRecordsHitEvent {
    NSCache *cache = [NSCache new];
    NSURL *url = [NSURL URLWithString:@"https://example.com/hit.png"];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return (NSURL *)key;
    }];

    // Prime the cache then look it up.
    [cache setObject:@"data" forKey:url];
    [self drainEventLog];
    [NRMANSCacheInstrumentation clearRecordedEvents];

    id result = [cache objectForKey:url];
    [self drainEventLog];

    XCTAssertNotNil(result, @"Object should be in cache");
    XCTAssertEqual([NRMANSCacheInstrumentation hitCount],  1u);
    XCTAssertEqual([NRMANSCacheInstrumentation missCount], 0u);

    NRMACacheEvent *event = [NRMANSCacheInstrumentation recordedEvents].firstObject;
    XCTAssertEqualObjects(event[@"url"], url.absoluteString);
    XCTAssertEqualObjects(event[@"hit"], @YES);
    XCTAssertNil(event[@"stored"], @"Lookup events must not carry a 'stored' key");
}

- (void)testObjectForKeyRecordsMissEvent {
    NSCache *cache = [NSCache new];
    NSURL *url = [NSURL URLWithString:@"https://example.com/miss.png"];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return (NSURL *)key;
    }];

    id result = [cache objectForKey:url];   // nothing stored — must be a miss
    [self drainEventLog];

    XCTAssertNil(result);
    XCTAssertEqual([NRMANSCacheInstrumentation missCount], 1u);
    XCTAssertEqual([NRMANSCacheInstrumentation hitCount],  0u);

    NRMACacheEvent *event = [NRMANSCacheInstrumentation recordedEvents].firstObject;
    XCTAssertEqualObjects(event[@"hit"], @NO);
}

// ---------------------------------------------------------------------------
#pragma mark - Unregistered cache
// ---------------------------------------------------------------------------

- (void)testUnregisteredCacheProducesNoEvents {
    NSCache *unregistered = [NSCache new];
    NSURL *url = [NSURL URLWithString:@"https://example.com/untracked.png"];

    [unregistered setObject:@"value" forKey:url];
    [unregistered objectForKey:url];
    [self drainEventLog];

    XCTAssertEqual([NRMANSCacheInstrumentation recordedEvents].count, 0u,
                   @"Unregistered caches must produce zero events");
}

// ---------------------------------------------------------------------------
#pragma mark - URL provider returning nil
// ---------------------------------------------------------------------------

- (void)testProviderReturningNilSuppressesEvent {
    NSCache *cache = [NSCache new];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return nil;   // opt out of every key
    }];

    [cache setObject:@"value" forKey:@"someKey"];
    [cache objectForKey:@"someKey"];
    [self drainEventLog];

    XCTAssertEqual([NRMANSCacheInstrumentation recordedEvents].count, 0u,
                   @"Provider returning nil must suppress the event");
}

//// ---------------------------------------------------------------------------
//#pragma mark - Counters across multiple events
//// ---------------------------------------------------------------------------
//
//- (void)testCountersAccumulateCorrectly {
//    NSCache *cache = [NSCache new];
//    NSURL *url1 = [NSURL URLWithString:@"https://example.com/a.png"];
//    NSURL *url2 = [NSURL URLWithString:@"https://example.com/b.png"];
//
//    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
//        return (NSURL *)key;
//    }];
//
//    [cache setObject:@"a" forKey:url1];       // store
//    [cache setObject:@"b" forKey:url2];       // store
//    [cache objectForKey:url1];                // hit
//    [cache objectForKey:url2];                // hit
//    [cache objectForKey:[NSURL URLWithString:@"https://example.com/c.png"]]; // miss
//    [self drainEventLog];
//
//    XCTAssertEqual([NRMANSCacheInstrumentation storeCount], 2u);
//    XCTAssertEqual([NRMANSCacheInstrumentation hitCount],   2u);
//    XCTAssertEqual([NRMANSCacheInstrumentation missCount],  1u);
//    XCTAssertEqual([NRMANSCacheInstrumentation recordedEvents].count, 5u);
//}

// ---------------------------------------------------------------------------
#pragma mark - hasCachedObjectForURL (reverse-index integration)
// ---------------------------------------------------------------------------

- (void)testHasCachedObjectForURLReturnsTrueAfterStore {
    NSCache *cache = [NSCache new];
    NSURL *url = [NSURL URLWithString:@"https://example.com/reverse.png"];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return (NSURL *)key;
    }];

    // Nothing stored yet — must be NO.
    [self drainReverseIndex];
    XCTAssertFalse([NRMANSCacheInstrumentation hasCachedObjectForURL:url],
                   @"URL not yet stored — hasCachedObjectForURL should return NO");

    [cache setObject:@"data" forKey:url];
    [self drainReverseIndex];

    XCTAssertTrue([NRMANSCacheInstrumentation hasCachedObjectForURL:url],
                  @"URL stored in registered NSCache — hasCachedObjectForURL should return YES");
}

- (void)testHasCachedObjectForURLReturnsFalseAfterEviction {
    NSCache *cache = [NSCache new];
    cache.totalCostLimit = 1;    // tiny limit forces eviction on second insert
    NSURL *url = [NSURL URLWithString:@"https://example.com/evict.png"];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return (NSURL *)key;
    }];

    [cache setObject:@"data" forKey:url cost:1];
    [self drainReverseIndex];

    // Evict by inserting a second object that exceeds the cost limit.
    NSURL *url2 = [NSURL URLWithString:@"https://example.com/evict2.png"];
    [cache setObject:@"data2" forKey:url2 cost:1];
    [self drainReverseIndex];

    // The first object should now be evicted; hasCachedObjectForURL probes the
    // original IMP so it returns NO for an evicted entry even though the reverse
    // index still holds a stale (url → cache, key) entry.
    XCTAssertFalse([NRMANSCacheInstrumentation hasCachedObjectForURL:url],
                   @"Evicted entry should return NO from hasCachedObjectForURL");
}

- (void)testHasCachedObjectForURLReturnsFalseForUnregisteredCache {
    NSCache *unregistered = [NSCache new];
    NSURL *url = [NSURL URLWithString:@"https://example.com/untracked2.png"];

    // Store without registering — reverse index never updated.
    [unregistered setObject:@"value" forKey:url];
    [self drainReverseIndex];

    XCTAssertFalse([NRMANSCacheInstrumentation hasCachedObjectForURL:url],
                   @"Unregistered cache should not appear in reverse index");
}

- (void)testHasCachedObjectForURLReturnsFalseForNilURL {
    XCTAssertFalse([NRMANSCacheInstrumentation hasCachedObjectForURL:nil]);
}

//// ---------------------------------------------------------------------------
//#pragma mark - clearRecordedEvents
//// ---------------------------------------------------------------------------
//
//- (void)testClearRecordedEventsResetsAllCounters {
//    NSCache *cache = [NSCache new];
//    NSURL *url = [NSURL URLWithString:@"https://example.com/img.png"];
//
//    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
//        return (NSURL *)key;
//    }];
//
//    [cache setObject:@"v" forKey:url];
//    [self drainEventLog];
//
//    XCTAssertEqual([NRMANSCacheInstrumentation storeCount], 1u);
//
//    [NRMANSCacheInstrumentation clearRecordedEvents];
//    [self drainEventLog];
//
//    XCTAssertEqual([NRMANSCacheInstrumentation recordedEvents].count, 0u);
//    XCTAssertEqual([NRMANSCacheInstrumentation storeCount], 0u);
//    XCTAssertEqual([NRMANSCacheInstrumentation hitCount],   0u);
//    XCTAssertEqual([NRMANSCacheInstrumentation missCount],  0u);
//}

//// ---------------------------------------------------------------------------
//#pragma mark - Nil safety
//// ---------------------------------------------------------------------------
//
//- (void)testSetNilObjectDoesNotCrashOrRecord {
//    NSCache *cache = [NSCache new];
//    NSURL *url = [NSURL URLWithString:@"https://example.com/nil.png"];
//
//    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
//        return (NSURL *)key;
//    }];
//
//    // NSCache silently ignores setObject:nil:, so this should not crash and
//    // the swizzle should also produce no event.
//    XCTAssertNoThrow([cache setObject:nil forKey:url]);
//    [self drainEventLog];
//
//    XCTAssertEqual([NRMANSCacheInstrumentation storeCount], 0u);
//}

- (void)testObjectForNilKeyDoesNotCrashOrRecord {
    NSCache *cache = [NSCache new];

    [NRMANSCacheInstrumentation registerCache:cache withURLProvider:^NSURL *(id key) {
        return (NSURL *)key;
    }];

    XCTAssertNoThrow([cache objectForKey:nil]);
    [self drainEventLog];

    XCTAssertEqual([NRMANSCacheInstrumentation recordedEvents].count, 0u);
}

// ---------------------------------------------------------------------------
#pragma mark - Helpers
// ---------------------------------------------------------------------------

/// Wait for all pending reverse-index writes to land.
///
/// _nrAppendCacheEvent enqueues reverse-index updates via dispatch_barrier_async
/// on the internal reverse-index queue.  +hasCachedObjectForURL: calls
/// dispatch_sync on that same queue, so it cannot return until every preceding
/// barrier write has completed.  Calling it here is sufficient to drain the queue.
- (void)drainReverseIndex {
    (void)[NRMANSCacheInstrumentation hasCachedObjectForURL:
               [NSURL URLWithString:@"https://example.com/__drain__"]];
}

/// Wait for all pending event-log writes to land.
///
/// _nrAppendCacheEvent enqueues via dispatch_barrier_async on the internal
/// event-log queue.  +recordedEvents calls dispatch_sync on that same queue,
/// so it cannot return until every preceding barrier write has completed.
/// Calling it here is sufficient to drain the queue before asserting.
- (void)drainEventLog {
    (void)[NRMANSCacheInstrumentation recordedEvents];
}

@end
