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

@interface NRMASAMTest : XCTestCase
{
}
@end

@implementation NRMASAMTest


- (NRMASAM*) samTest {
    return [[NRMASAM alloc] initWithAttributeValidator:[[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
        if ([name length] == 0) {
            NRLOG_ERROR(@"invalid attribute: name length = 0");
            return false;
        }
        if ([name hasPrefix:@" "]) {
            NRLOG_ERROR(@"invalid attribute: name prefix = \" \"");
            return false;
        }
        // check if attribute name is reserved or attribute name matches reserved prefix.
        for (NSString* key in [NRMAAnalytics reservedKeywords]) {
            if ([key isEqualToString:name]) {
                NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
                return false;
            }
            if ([key hasPrefix:name])  {
                NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
                return false;
            }
        }
        // check if attribute name exceeds max length.
        if ([name length] > kNRMA_Attrib_Max_Name_Length) {
            NRLOG_ERROR(@"invalid attribute: name length exceeds limit");
            return false;
        }
        return true;

    } valueValidator:^BOOL(id value) {
        if ([value isKindOfClass:[NSString class]]) {
            unsigned long length = [(NSString*)value length];
            if (length == 0) {
                NRLOG_ERROR(@"invalid attribute: value length = 0");
                return false;
            }
            else if (length >= kNRMA_Attrib_Max_Value_Size_Bytes) {
                NRLOG_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
                return false;
            }
        }
        if (value == nil) {
            NRLOG_ERROR(@"invalid attribute: value cannot be nil");
            return false;
        }

        return true;
    } andEventTypeValidator:^BOOL(NSString *eventType) {
        return YES;
    }]];
}

- (void) testSetSessionAttribute {
    NRMASAM *manager = [self samTest];
    XCTAssertTrue([manager setSessionAttribute:@"blarg" value:@"blurg"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg"] isEqualToString:@"blurg"]);
}

- (void) testSetNRSessionAttribute {
    NRMASAM *manager = [self samTest];
    XCTAssertTrue([manager setNRSessionAttribute:@"blarg" value:@"blurg"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg"] isEqualToString:@"blurg"]);
}

- (void) testIncrementSessionAttribute {
    NRMASAM *manager = [self samTest];
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
    NRMASAM *manager = [self samTest];
    NSString* attribute = @"incrementableAttribute";
    float initialValue = 1.2;

    XCTAssertTrue([manager setSessionAttribute:attribute value:@(initialValue)], @"Failed to successfully set session attribute");

    double incrementValue = 1.23;
    [manager incrementSessionAttribute:attribute value:@(incrementValue)];

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    float newValue =  [decode[attribute] floatValue];

    XCTAssertEqualWithAccuracy(newValue, 2.43, 0.01);
}

- (void) testSetUserId {
    NRMASAM *manager = [self samTest];
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
    NRMASAM *manager = [self samTest];
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
    NRMASAM *manager = [self samTest];
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
    NRMASAM *manager = [self samTest];

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
    NRMASAM *manager = [self samTest];

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
    NRMASAM *manager = [self samTest];
    NSString *attribute = @"blarg";
    NSString *attribute2 = @"blarg2";

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2"], @"Failed to successfully set session attribute");

    [manager clearLastSessionsAnalytics];
    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertEqual(decode.count, 0, @"Should have emptied session attributes.");


}

- (void) testClearPersistedSessionAnalytics {
    NRMASAM *manager = [self samTest];
    NSString *attribute = @"blarg";
    NSString *attribute2 = @"blarg2";

    NSString *attribute3 = @"privateBlarg3";

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg"], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2"], @"Failed to successfully set session attribute");

    XCTAssertTrue([manager setNRSessionAttribute:attribute3 value:@"blurg2"], @"Failed to successfully set private session attribute");


    [manager clearPersistedSessionAnalytics];
    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertEqual(decode.count, 0, @"Should have emptied session attributes.");


    NSString *publicAttributePath = [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:publicAttributePath], @"Data had value but it should be nil");


    NSString *privateAttributePath = [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file_private];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:privateAttributePath], @"Private Data had value but it should be nil");

}

-(void) testSetSessionAttributeNameFailed {
    NRMASAM *manager = [self samTest];

    // Test Invalid Attribute Name cases.
    XCTAssertFalse([manager setSessionAttribute:@"" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");
    XCTAssertFalse([manager setSessionAttribute:@"  x" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");
    XCTAssertFalse([manager setSessionAttribute:@"  " value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");

    XCTAssertFalse([manager setSessionAttribute:@"even" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");
    XCTAssertFalse([manager setSessionAttribute:@"event" value:@"blurg"], @"Failed to successfully fail when setting invalid name for session attribute");

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
    NRMASAM *manager = [self samTest];

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


@end
