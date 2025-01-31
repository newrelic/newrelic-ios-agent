//
//  NRMASAMTest.mm
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMASAM.h"
#import "NRLogger.h"
#import "NewRelicInternalUtils.h"
#import "NRMAAnalytics.h"
#import "Constants.h"
#import "NRMABool.h"

@interface NRMASAMTest : XCTestCase
{
    NRMASAM *manager;
}
@end

@implementation NRMASAMTest

- (void)setUp {
    [super setUp];
    [NRLogger setLogLevels:NRLogLevelDebug];

    manager = [self samTest];
    [manager removeAllSessionAttributes];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file]]) {
        [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file] error:nil];
    }
    if([fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file_private]]) {
        [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file_private] error:nil];
    }
}

- (NRMASAM*) samTest {
    return [[NRMASAM alloc] initWithAttributeValidator:[[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
        if ([name length] == 0) {
            NRLOG_AGENT_ERROR(@"invalid attribute: name length = 0");
            return NO;
        }
        if ([name hasPrefix:@" "]) {
            NRLOG_AGENT_ERROR(@"invalid attribute: name prefix = \" \"");
            return NO;
        }
        // check if attribute name is reserved or attribute name matches reserved prefix.
        for (NSString* key in [NRMAAnalytics reservedKeywords]) {
            if ([key isEqualToString:name]) {
                NRLOG_AGENT_ERROR(@"invalid attribute: name disallowed");
                return NO;
            }
        }
        for (NSString* key in [NRMAAnalytics reservedPrefixes]) {
            if ([name hasPrefix:key])  {
                NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
                return false;
            }
        }
        // check if attribute name exceeds max length.
        if ([name length] > kNRMA_Attrib_Max_Name_Length) {
            NRLOG_AGENT_ERROR(@"invalid attribute: name length exceeds limit");
            return NO;
        }
        return YES;

    } valueValidator:^BOOL(id value) {
        if ([value isKindOfClass:[NSString class]]) {
            unsigned long length = [(NSString*)value length];
            if (length == 0) {
                NRLOG_AGENT_ERROR(@"invalid attribute: value length = 0");
                return NO;
            }
            else if (length >= kNRMA_Attrib_Max_Value_Size_Bytes) {
                NRLOG_AGENT_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
                return NO;
            }
        }
        if (value == nil) {
            NRLOG_AGENT_ERROR(@"invalid attribute: value cannot be nil");
            return NO;
        }

        return true;
    } andEventTypeValidator:^BOOL(NSString *eventType) {
        return YES;
    }]];
}

- (void) testSetSessionAttribute {
    XCTAssertTrue([manager setSessionAttribute:@"blarg" value:@"blurg"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg"] isEqualToString:@"blurg"]);
}

- (void) testSetSessionAttributeFail {
    XCTAssertFalse([manager setSessionAttribute:@"platform" value:@"blurg"], @"Failed to successfully find reserved key for session attribute");

    XCTAssertFalse([manager setSessionAttribute:@"nr.test" value:@"blurg"], @"Failed to successfully find reserved prefix key for session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertNil(decode[@"platform"]);
}

- (void) testSetNRSessionAttribute {
    XCTAssertTrue([manager setNRSessionAttribute:@"blarg" value:@"blurg"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg"] isEqualToString:@"blurg"]);
}

- (void) testIncrementSessionAttribute {
    NSString* attribute = @"incrementableAttribute";
    XCTAssertTrue([manager setSessionAttribute:attribute value:@(1)], @"Failed to successfully set session attribute");
    [manager incrementSessionAttribute:attribute value:@(1)];

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[attribute] isEqual:@(2)]);
}

- (void) testIncrementSessionAttributeDiffTypes {
    NSString* attribute = @"incrementableAttribute";
    float initialValue = 1.2;

    XCTAssertTrue([manager setSessionAttribute:attribute value:@(initialValue)], @"Failed to successfully set session attribute");

    double incrementValue = 1.23;
    XCTAssertTrue([manager incrementSessionAttribute:attribute value:@(incrementValue)]);

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    float newValue =  [decode[attribute] floatValue];

    XCTAssertEqualWithAccuracy(newValue, 2.43, 0.01);
}

- (void) testSetUserId {
    NSString* attribute = @"userId";
    NSString* userIdValue = @"AUniqueId7";
    XCTAssertTrue([manager setUserId:userIdValue]);


    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[attribute] isEqualToString:userIdValue]);
}

- (void) testRemoveSessionAttributeNamed {
    NSString *attribute = @"blarg";
    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    NSString* attributes = [manager sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[attribute] isEqualToString:@"blurg"]);

    XCTAssertTrue([manager removeSessionAttributeNamed:attribute]);

    NSString* attributes2 = [manager sessionAttributeJSONString];
    NSDictionary* decode2 = [NSJSONSerialization JSONObjectWithData:[attributes2 dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:nil];
    XCTAssertNil(decode2[attribute],@"attribute not removed when it should have been.");
}

- (void) testRemoveAllSessionAttributes {
    NSString *attribute = @"blarg";
    NSString *attribute2 = @"blarg2";

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];

    XCTAssertTrue([decode[attribute] isEqualToString:@"blurg"]);
    XCTAssertTrue([decode[attribute2] isEqualToString:@"blurg2"]);
    XCTAssertTrue([manager removeAllSessionAttributes]);

    NSString* attributes2 = [manager sessionAttributeJSONString];
    NSDictionary* decode2 = [NSJSONSerialization JSONObjectWithData:[attributes2 dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:nil];
    XCTAssertEqual(decode2.count, 0, @"attributes not removed when they should have been.");
}

- (void) testSetNRSessionAttributesToMaxAndAddUserAttribute {

    for (int i = 0; i < kNRMA_Attrib_Max_Number_Attributes; i++) {
        NSString *newName = [NSString stringWithFormat:@"blarg%d",i];

        XCTAssertTrue([manager setNRSessionAttribute:newName value:@"blurg"], @"Failed to successfully set session attribute");
    }

    XCTAssertTrue([manager setSessionAttribute:@"userDefined" value:@"userDefinedValue"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg0"] isEqualToString:@"blurg"]);
    XCTAssertTrue([decode[@"userDefined"] isEqualToString:@"userDefinedValue"]);
}

- (void) testMaxUserAttributes {

    // Fill to max private session Attribute
    for (int i = 0; i < kNRMA_Attrib_Max_Number_Attributes; i++) {
        NSString *newName = [NSString stringWithFormat:@"blarg%d",i];

        XCTAssertTrue([manager setNRSessionAttribute:newName value:@"blurg"], @"Failed to successfully set session attribute");
    }

    for (int i = 0; i < kNRMA_Attrib_Max_Number_Attributes; i++) {
        NSString *newName = [NSString stringWithFormat:@"userDefined%d",i];

        XCTAssertTrue([manager setSessionAttribute:newName value:@"userDefinedValue"], @"Failed to successfully set session attribute");

    }
    XCTAssertFalse([manager setSessionAttribute:@"userDefined129" value:@"userDefinedValue"], @"Failed to fail when adding user defined session attribute which exceeds limit.");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];

    XCTAssertTrue([decode[@"userDefined0"] isEqualToString:@"userDefinedValue"]);
}

- (void) testClearLastSessionsAnalytics {
    NSString *attribute = @"blarg";
    NSString *attribute2 = @"blarg2";

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2"], @"Failed to successfully set session attribute");

    [manager removeAllSessionAttributes];
    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertEqual(decode.count, 0, @"Should have emptied session attributes.");


}

- (void)waitForAttributesToPersist:(NSArray<NSString *> *)expectedAttributes timeout:(NSTimeInterval)timeout {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([timeoutDate timeIntervalSinceNow] > 0) {
        NSString *attributes = [NRMASAM getLastSessionsAttributes];
        NSDictionary *decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        
        BOOL allAttributesPersisted = YES;
        for (NSString *attribute in expectedAttributes) {
            if (![decode objectForKey:attribute]) {
                allAttributesPersisted = NO;
                break;
            }
        }

        if (allAttributesPersisted) {
            return;
        }

        // Wait a short period before retrying
        [NSThread sleepForTimeInterval:0.1];
    }    
    XCTFail(@"Failed to persist expected attributes.");
}

- (void)testPersistedSessionAnalytics {
    
    NSString *attribute = @"blarg";
    NSString *attribute2 = @"blarg2";
    NSString *attribute3 = @"privateBlarg3";
    NSString *attribute4 = @"Blarg4";
    NSString *attribute5 = @"privateBlarg5";

    // Set attributes
    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setNRSessionAttribute:attribute3 value:@"blurg2"], @"Failed to successfully set private session attribute");
    
    NSString *attributes = [manager sessionAttributeJSONString];
    NSDictionary *decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    XCTAssertEqual(decode.count, 3);
    
    manager = nil;
    // Wait for persistence
    [self waitForAttributesToPersist:@[attribute, attribute2, attribute3] timeout:10];

    manager = [self samTest];

    XCTAssertTrue([manager setSessionAttribute:attribute4 value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setNRSessionAttribute:attribute5 value:@"blurg2"], @"Failed to successfully set private session attribute");

    attributes = [manager sessionAttributeJSONString];
    decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    XCTAssertTrue([[decode allKeys] containsObject:attribute], @"Should have persisted and new attribute 1.");
    XCTAssertTrue([[decode allKeys] containsObject:attribute2], @"Should have persisted and new attribute 2.");
    XCTAssertTrue([[decode allKeys] containsObject:attribute3], @"Should have persisted and new private attribute 3.");
    XCTAssertTrue([[decode allKeys] containsObject:attribute4], @"Should have persisted and new attribute 4.");
    XCTAssertTrue([[decode allKeys] containsObject:attribute5], @"Should have persisted and new private attribute 5.");
}

- (void) testClearPersistedSessionAnalytics {
    NSString *attribute = @"blarg";
    NSString *attribute2 = @"blarg2";

    NSString *attribute3 = @"privateBlarg3";

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2"], @"Failed to successfully set session attribute");

    XCTAssertTrue([manager setNRSessionAttribute:attribute3 value:@"blurg2"], @"Failed to successfully set private session attribute");


    [manager removeAllSessionAttributes];
    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertEqual(decode.count, 0, @"Should have emptied session attributes.");
}

-(void) testSetSessionAttributeNameFailed {

    // Test Invalid Attribute Name cases.
    XCTAssertFalse([manager setSessionAttribute:@"" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");
    XCTAssertFalse([manager setSessionAttribute:@"  x" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");
    XCTAssertFalse([manager setSessionAttribute:@"  " value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");

    XCTAssertFalse([manager setSessionAttribute:@"newRelictest" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");
    XCTAssertFalse([manager setSessionAttribute:@"nr.test" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");

    // Test Max Attribute Length
    NSString *validAttributeName =  [@"" stringByPaddingToLength:kNRMA_Attrib_Max_Name_Length withString:@"x" startingAtIndex:0];
    XCTAssertTrue([manager setSessionAttribute:validAttributeName value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");

    NSString *invalidAttributeName =  [@"" stringByPaddingToLength:kNRMA_Attrib_Max_Name_Length+1 withString:@"x" startingAtIndex:0];
    XCTAssertFalse([manager setSessionAttribute:invalidAttributeName value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");


    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    // valid attrib was added
    XCTAssertEqual(decode.count, 1);

}

-(void) testSetSessionAttributeValueFailed {

    // Test Invalid Attribute Value cases.
    XCTAssertFalse([manager setSessionAttribute:@"blarg" value:@""], @"Failed to successfully fail when setting invalid value for session attribute");

    // Test Max Attribute Length

    NSString *validValue =  [@"" stringByPaddingToLength:4095 withString:@"x" startingAtIndex:0];
    XCTAssertTrue([manager setSessionAttribute:@"blarg" value:validValue], @"Failed to successfully fail when setting invalid name for session attribute");

    NSString *invalidValue =  [@"" stringByPaddingToLength:4096 withString:@"x" startingAtIndex:0];
    XCTAssertFalse([manager setSessionAttribute:@"blarg" value:invalidValue], @"Failed to successfully fail when setting invalid name for session attribute");

    XCTAssertFalse([manager setSessionAttribute:@"blarg" value:nil], @"Failed to successfully fail when setting invalid name for session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    // valid attrib was added
    XCTAssertEqual(decode.count, 1);

}

- (void)testIncrementIntegerValueWithDouble {
    NSString *attribute = @"incrementableAttribute";
    unsigned long long initialIntegerValue = 24;

    XCTAssertTrue([manager setSessionAttribute:attribute value:@(initialIntegerValue)], @"Failed to successfully set session attribute");

    double incrementValue = 1.23;
    XCTAssertTrue([manager incrementSessionAttribute:attribute value:@(incrementValue)]);

    NSString* attributes = [manager sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    unsigned long long newValue =  [decode[attribute] unsignedLongLongValue];

    XCTAssertEqualWithAccuracy(newValue, 25, 0.01);
}

- (void)testIncrementDoubleValueWithInteger {
    NSString *attribute = @"incrementableAttribute";
    double initialDoubleValue = 1.2;

    XCTAssertTrue([manager setSessionAttribute:attribute value:@(initialDoubleValue)], @"Failed to successfully set session attribute");

    unsigned long long incrementValue = 3;
    [manager incrementSessionAttribute:attribute value:@(incrementValue)];

    NSString* attributes = [manager sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    double newValue =  [decode[attribute] doubleValue];

    XCTAssertEqualWithAccuracy(newValue, 4.2, 0.01);
}

- (void)testCantIncrementStrings {
    NSString *attribute = @"unincrementableAttribute";

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"Should not be incremented"], @"Failed to successfully set session attribute");

    XCTAssertFalse([manager incrementSessionAttribute:attribute value:@(20)]);
}

- (void)testCantIncrementBool {
    NSString *attribute = @"unincrementableAttribute";
    NRMABool *initialValue = [[NRMABool alloc] initWithBOOL:NO];

    XCTAssertTrue([manager setSessionAttribute:attribute value:initialValue], @"Failed to successfully set session attribute");

    XCTAssertFalse([manager incrementSessionAttribute:attribute value:@(20)]);
}

- (void)testCantAddNonNumberToNumber {
    NSString *attribute = @"incrementableAttributeBadValue";

    double initialDoubleValue = 1.2;

    XCTAssertTrue([manager setSessionAttribute:attribute value:@(initialDoubleValue)], @"Failed to successfully set session attribute");

    XCTAssertFalse([manager incrementSessionAttribute:attribute value:[NSNumber numberWithBool:YES]]);
}

@end
