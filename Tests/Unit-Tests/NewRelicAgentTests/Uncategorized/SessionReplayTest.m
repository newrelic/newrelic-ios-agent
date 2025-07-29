//
//  SessionReplayTest.m
//  NewRelicAgent
//
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NewRelicAgentInternal.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvesterConfiguration.h"

@interface SessionReplayTest : XCTestCase
@property id mockNewRelicInternals;
@property id mockHarvestController;
@property NRMAHarvesterConfiguration *harvesterConfiguration;
@end

@implementation SessionReplayTest

- (void)setUp {
    [super setUp];
    self.mockNewRelicInternals = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    self.mockHarvestController = [OCMockObject mockForClass:[NRMAHarvestController class]];
    
    // Get a real configuration instance to test with
    self.harvesterConfiguration = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [[[[self.mockHarvestController stub] classMethod] andReturn:self.harvesterConfiguration] configuration];
}

- (void)tearDown {
    [super tearDown];
    
    [self.mockHarvestController stopMocking];
    [self.mockNewRelicInternals stopMocking];
}

// Tests for Accessibility Identifier masking
- (void)testAccessibilityIdentifierMasking {
    // Test adding a masked accessibility identifier
    NSString *testIdentifier = @"sensitiveField";
    NSArray *identifierArray = @[testIdentifier];
    [self.harvesterConfiguration addMaskedAccessibilityIdentifiers:identifierArray];
    
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:testIdentifier],
                  @"Identifier should be in masked list after adding");

    // Test masking check for non-added identifier
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:@"nonSensitiveField"],
                   @"Non-added identifier should not be in masked list");

    // Test removing a masked accessibility identifier
    [self.harvesterConfiguration removeMaskedAccessibilityIdentifier:testIdentifier];
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:testIdentifier],
                   @"Identifier should not be in masked list after removing");

    // Test adding multiple identifiers
    NSString *identifier1 = @"sensitiveField1";
    NSString *identifier2 = @"sensitiveField2";
    [self.harvesterConfiguration addMaskedAccessibilityIdentifiers:@[identifier1]];
    [self.harvesterConfiguration addMaskedAccessibilityIdentifiers:@[identifier2]];
    
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:identifier1],
                  @"First identifier should be in masked list");
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:identifier2],
                  @"Second identifier should be in masked list");
}

// Tests for Class Name masking
- (void)testClassNameMasking {
    // Test adding a masked class name
    NSString *testClassName = @"CustomTextField";
    [self.harvesterConfiguration addMaskedClassNames:@[testClassName]];
    
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:testClassName],
                  @"Class name should be in masked list after adding");

    // Test masking check for non-added class name
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:@"CustomTextField2"],
                   @"Non-added class name should not be in masked list");

    // Test removing a masked class name
    [self.harvesterConfiguration removeMaskedClassName:testClassName];
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:testClassName],
                   @"Class name should not be in masked list after removing");

    // Test adding multiple class names
    NSString *className1 = @"CustomTextField";
    NSString *className2 = @"CustomTextView";
    [self.harvesterConfiguration addMaskedClassNames:@[className1]];
    [self.harvesterConfiguration addMaskedClassNames:@[className2]];
    
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:className1],
                  @"First class name should be in masked list");
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:className2],
                  @"Second class name should be in masked list");
}

// Test for edge cases
- (void)testMaskingEdgeCases {
//    // Test with empty strings
//    NSString *emptyString = @"";
//    [self.harvesterConfiguration addMaskedAccessibilityIdentifiers:@[emptyString]];
//    [self.harvesterConfiguration addMaskedClassNames:@[emptyString]];
//    
//    // Empty strings should not be added to the arrays
//    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:emptyString],
//                   @"Empty string identifier should not be in masked list");
//    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:emptyString],
//                   @"Empty string class name should not be in masked list");

    // Test with nil (should not crash)
    XCTAssertNoThrow([self.harvesterConfiguration addMaskedAccessibilityIdentifiers:nil],
                     @"Adding nil accessibility identifier array should not throw");
    XCTAssertNoThrow([self.harvesterConfiguration addMaskedClassNames:nil],
                     @"Adding nil class name array should not throw");
    XCTAssertNoThrow([self.harvesterConfiguration removeMaskedAccessibilityIdentifier:nil],
                     @"Removing nil class name should not throw");
}

- (void)testAccessibilityIdentifierUnmasking {
    // Test unmasking an identifier that was never masked
    NSString *unmaskedIdentifier = @"unmaskedField";
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:unmaskedIdentifier],
                   @"Unmasked identifier should not be in masked list");

    // Test unmasking a previously masked identifier
    NSString *maskedIdentifier = @"sensitiveField";
    [self.harvesterConfiguration addMaskedAccessibilityIdentifiers:@[maskedIdentifier]];
    XCTAssertTrue([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:maskedIdentifier],
                  @"Identifier should be in masked list after adding");
    
    [self.harvesterConfiguration removeMaskedAccessibilityIdentifier:maskedIdentifier];
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedAccessibilityIdentifiers containsObject:maskedIdentifier],
                   @"Identifier should not be in masked list after removing");

    // Test unmasking with the addUnmaskedAccessibilityIdentifiers method
    NSString *anotherMaskedIdentifier = @"anotherSensitiveField";
    [self.harvesterConfiguration addMaskedAccessibilityIdentifiers:@[anotherMaskedIdentifier]];
    [self.harvesterConfiguration addUnmaskedAccessibilityIdentifiers:@[anotherMaskedIdentifier]];
    
    // Test unmasking a class name that was never masked
    NSString *unmaskedClassName = @"UnmaskedClass";
    XCTAssertFalse([self.harvesterConfiguration.session_replay_maskedClassNames containsObject:unmaskedClassName],
                   @"Unmasked class name should not be in masked list");
}

@end
