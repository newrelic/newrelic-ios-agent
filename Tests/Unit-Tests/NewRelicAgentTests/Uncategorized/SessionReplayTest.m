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

@interface SessionReplayTest : XCTestCase
@property id mockNewRelicInternals;
@property id mockHarvestController;

@end
static NewRelicAgentInternal* _sharedInstance;

@implementation SessionReplayTest

- (void)setUp {
    [super setUp];
    self.mockNewRelicInternals = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    _sharedInstance = [[NewRelicAgentInternal alloc] init];
    [[[[self.mockNewRelicInternals stub] classMethod] andReturn:_sharedInstance] sharedInstance];
    
    self.mockHarvestController = [OCMockObject mockForClass:[NRMAHarvestController class]];
    [[[[self.mockHarvestController stub] classMethod] andReturn:[NRMAHarvesterConfiguration defaultHarvesterConfiguration]] configuration];
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
    [[NewRelicAgentInternal sharedInstance] addMaskedAccessibilityIdentifier:testIdentifier];
    XCTAssertTrue([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:testIdentifier], @"Identifier should be masked after adding");

    // Test masking check for non-added identifier
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:@"nonSensitiveField"], @"Non-added identifier should not be masked");

    // Test removing a masked accessibility identifier
    [[NewRelicAgentInternal sharedInstance]  removeMaskedAccessibilityIdentifier:testIdentifier];
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:testIdentifier], @"Identifier should not be masked after removing");

    // Test adding multiple identifiers
    NSString *identifier1 = @"sensitiveField1";
    NSString *identifier2 = @"sensitiveField2";
    [[NewRelicAgentInternal sharedInstance]  addMaskedAccessibilityIdentifier:identifier1];
    [[NewRelicAgentInternal sharedInstance]  addMaskedAccessibilityIdentifier:identifier2];
    XCTAssertTrue([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:identifier1], @"First identifier should be masked");
    XCTAssertTrue([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:identifier2], @"Second identifier should be masked");
}

// Tests for Class Name masking
- (void)testClassNameMasking {
    // Test adding a masked class name
    NSString *testClassName = @"CustomTextField";
    [[NewRelicAgentInternal sharedInstance]  addMaskedClassName:testClassName];
    XCTAssertTrue([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:testClassName], @"Class name should be masked after adding");

    // Test masking check for non-added class name
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:@"CustomTextField2"], @"Non-added class name should not be masked");

    // Test removing a masked class name
    [[NewRelicAgentInternal sharedInstance]  removeMaskedClassName:testClassName];
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:testClassName], @"Class name should not be masked after removing");

    // Test adding multiple class names
    NSString *className1 = @"CustomTextField";
    NSString *className2 = @"CustomTextView";
    [[NewRelicAgentInternal sharedInstance]  addMaskedClassName:className1];
    [[NewRelicAgentInternal sharedInstance]  addMaskedClassName:className2];
    XCTAssertTrue([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:className1], @"First class name should be masked");
    XCTAssertTrue([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:className2], @"Second class name should be masked");
}

// Test for edge cases
- (void)testMaskingEdgeCases {
    // Test with empty strings
    NSString *emptyString = @"";
    [[NewRelicAgentInternal sharedInstance]  addMaskedAccessibilityIdentifier:emptyString];
    [[NewRelicAgentInternal sharedInstance]  addMaskedClassName:emptyString];
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:emptyString], @"Empty string identifier should not be masked");
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:emptyString], @"Empty string class name should not be masked");

    // Test with nil (should not crash)
    // Note: Objective-C methods should handle nil gracefully, but these tests verify that behavior
    XCTAssertNoThrow([[NewRelicAgentInternal sharedInstance]  addMaskedAccessibilityIdentifier:nil], @"Adding nil accessibility identifier should not throw");
    XCTAssertNoThrow([[NewRelicAgentInternal sharedInstance]  addMaskedClassName:nil], @"Adding nil class name should not throw");
    XCTAssertNoThrow([[NewRelicAgentInternal sharedInstance] removeMaskedAccessibilityIdentifier:nil], @"Removing nil accessibility identifier should not throw");
    XCTAssertNoThrow([[NewRelicAgentInternal sharedInstance] removeMaskedClassName:nil], @"Removing nil class name should not throw");

    // Verify nil checks
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:nil], @"Nil identifier should not be considered masked");
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:nil], @"Nil class name should not be considered masked");
}


- (void)testAccessibilityIdentifierUnmasking {

    // Test unmasking an identifier that was never masked
    NSString *unmaskedIdentifier = @"unmaskedField";
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:unmaskedIdentifier], @"Unmasked identifier should not be considered masked");

    // Test unmasking a previously masked identifier
    NSString *maskedIdentifier = @"sensitiveField";
    [[NewRelicAgentInternal sharedInstance]  addUnmaskedAccessibilityIdentifier:maskedIdentifier];
    [[NewRelicAgentInternal sharedInstance]  removeMaskedAccessibilityIdentifier:maskedIdentifier];
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isAccessibilityIdentifierMasked:maskedIdentifier], @"Identifier should not be masked after unmasking");

    // Test unmasking a class name that was never masked
    NSString *unmaskedClassName = @"UnmaskedClass";
    XCTAssertFalse([[NewRelicAgentInternal sharedInstance]  isClassNameMasked:unmaskedClassName], @"Unmasked class name should not be considered masked");
}

@end
