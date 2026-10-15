//
//  NRMAViewContextPersistenceTests.m
//  NewRelicAgent
//
//  Covers the referrer state that survives a crash: currentViewInstanceId in referrerAttributes
//  (needed so a decorated crash/request/handled-exception event can join back to the exact view
//  instance, not just its name), and the disk-backed snapshot a crash report is decorated from on
//  next launch, since NRMAViewContext's in-memory state does not survive the crash itself.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAViewContext.h"
#import "NRMAFlags.h"
#import "NewRelic.h"

@interface NRMAViewContextPersistenceTests : XCTestCase
@end

@implementation NRMAViewContextPersistenceTests {
    NRMAViewContext *_context;
}

- (void)setUp {
    [super setUp];
    [NRMAViewContext clearPersistedReferrerAttributes];
    _context = [[NRMAViewContext alloc] init];
    [NewRelic enableFeatures:NRFeatureFlag_AutomaticMobileViews];
}

- (void)tearDown {
    [NewRelic disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    [NRMAViewContext clearPersistedReferrerAttributes];
    _context = nil;
    [super tearDown];
}

#pragma mark - referrerAttributes exposes currentViewInstanceId

- (void)testReferrerAttributesIncludesCurrentViewInstanceId {
    [_context transitionToView:@"Dashboard" instanceId:@"ID-DASH" appearTime:CFAbsoluteTimeGetCurrent()];

    NSDictionary *attrs = [_context referrerAttributes];

    XCTAssertEqualObjects(attrs[@"currentViewInstanceId"], @"ID-DASH");
}

- (void)testReferrerAttributesOmitsCurrentViewInstanceIdWhenNoViewIsCurrent {
    NSDictionary *attrs = [_context referrerAttributes];

    XCTAssertNil(attrs[@"currentViewInstanceId"]);
}

#pragma mark - persisted state survives past this instance

- (void)testPersistedReferrerAttributesReflectsLastTransition {
    [_context transitionToView:@"Dashboard" instanceId:@"ID-DASH" appearTime:CFAbsoluteTimeGetCurrent()];
    [_context transitionToView:@"Charts" instanceId:@"ID-CHARTS" appearTime:CFAbsoluteTimeGetCurrent()];

    NSDictionary<NSString *, NSString *> *persisted = [NRMAViewContext persistedReferrerAttributes];

    XCTAssertEqualObjects(persisted[@"currentView"], @"Charts");
    XCTAssertEqualObjects(persisted[@"currentViewInstanceId"], @"ID-CHARTS");
    XCTAssertEqualObjects(persisted[@"previousView"], @"Dashboard");
    XCTAssertEqualObjects(persisted[@"previousViewInstanceId"], @"ID-DASH");
}

- (void)testPersistedReferrerAttributesIsNilWhenNothingWasEverPersisted {
    XCTAssertNil([NRMAViewContext persistedReferrerAttributes]);
}

- (void)testClearPersistedReferrerAttributesRemovesWhatWasWritten {
    [_context transitionToView:@"Dashboard" instanceId:@"ID-DASH" appearTime:CFAbsoluteTimeGetCurrent()];
    XCTAssertNotNil([NRMAViewContext persistedReferrerAttributes]);

    [NRMAViewContext clearPersistedReferrerAttributes];

    XCTAssertNil([NRMAViewContext persistedReferrerAttributes]);
}

- (void)testManualViewTransitionIsAlsoPersisted {
    [_context setCurrentManualView:@"Cart" attributes:nil];

    NSDictionary<NSString *, NSString *> *persisted = [NRMAViewContext persistedReferrerAttributes];

    XCTAssertEqualObjects(persisted[@"currentView"], @"Cart");
}

#pragma mark - mergeReferrerAttributesInto: (shared by breadcrumbs, MobileRequest,
#pragma mark   MobileRequestError, and Handled Exceptions per IDD §5.5/§11 Q7)

- (void)testMergeReferrerAttributesReturnsAttributesUnchangedWhenNoMobileViewsFlagEnabled {
    [NewRelic disableFeatures:NRFeatureFlag_AutomaticMobileViews];
    NSDictionary *attributes = @{@"custom": @"value"};

    NSDictionary *merged = [NRMAViewContext mergeReferrerAttributesInto:attributes];

    XCTAssertEqualObjects(merged, attributes);
}

- (void)testMergeReferrerAttributesReturnsNilUnchangedWhenNoMobileViewsFlagEnabled {
    [NewRelic disableFeatures:NRFeatureFlag_AutomaticMobileViews];

    XCTAssertNil([NRMAViewContext mergeReferrerAttributesInto:nil]);
}

- (void)testMergeReferrerAttributesAddsCurrentViewWhenEnabledAndViewIsSet {
    [[NRMAViewContext sharedInstance] transitionToView:@"MergeTestView"
                                             instanceId:@"MERGE-1"
                                             appearTime:CFAbsoluteTimeGetCurrent()];

    NSDictionary *merged = [NRMAViewContext mergeReferrerAttributesInto:@{@"custom": @"value"}];

    XCTAssertEqualObjects(merged[@"custom"], @"value");
    XCTAssertEqualObjects(merged[@"currentView"], @"MergeTestView");
    XCTAssertEqualObjects(merged[@"currentViewInstanceId"], @"MERGE-1");
}

- (void)testMergeReferrerAttributesAgentOwnedKeyWinsOverCallerSuppliedValue {
    [[NRMAViewContext sharedInstance] transitionToView:@"OverrideTestView"
                                             instanceId:@"MERGE-2"
                                             appearTime:CFAbsoluteTimeGetCurrent()];

    NSDictionary *merged = [NRMAViewContext mergeReferrerAttributesInto:@{@"currentView": @"CallerSuppliedNonsense"}];

    XCTAssertEqualObjects(merged[@"currentView"], @"OverrideTestView");
}

@end
