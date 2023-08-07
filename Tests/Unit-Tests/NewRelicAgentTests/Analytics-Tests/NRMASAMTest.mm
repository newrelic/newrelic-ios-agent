//
//  NRMASAMTest.mm
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMASAM.h"
#import "NRMAAnalyticsConstants.h"
#import "NRLogger.h"

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
        for (NSString* key in reservedKeywords) {
            if ([key isEqualToString:name]) {
                NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
                return false;
            }
            if ([name hasPrefix:key])  {
                NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
                return false;
            }
        }
        // check if attribute name exceeds max length.
        if ([name length] > maxNameLength) {
            NRLOG_ERROR(@"invalid attribute: name length exceeds limit");
            return false;
        }
        return true;

    } valueValidator:^BOOL(id value) {
        if ([value isKindOfClass:[NSString class]]) {
            if ([(NSString*)value length] == 0) {
                NRLOG_ERROR(@"invalid attribute: value length = 0");
                return false;
            }
            else if ([(NSString*)value length] >= maxValueSizeBytes) {
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
    XCTAssertTrue([manager setSessionAttribute:@"blarg" value:@"blurg" persistent:true], @"Failed to successfully set session attribute");

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
    XCTAssertTrue([manager setSessionAttribute:attribute value:@(1) persistent:true], @"Failed to successfully set session attribute");
    [manager incrementSessionAttribute:attribute value:@(1) persistent:true];

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

    XCTAssertTrue([manager setSessionAttribute:attribute value:@(initialValue) persistent:true], @"Failed to successfully set session attribute");

    double incrementValue = 1.23;
    [manager incrementSessionAttribute:attribute value:@(incrementValue) persistent:true];

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
    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg" persistent:true], @"Failed to successfully set session attribute");
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

    XCTAssertTrue([manager setSessionAttribute:attribute value:@"blurg" persistent:true], @"Failed to successfully set session attribute");
    XCTAssertTrue([manager setSessionAttribute:attribute2 value:@"blurg2" persistent:true], @"Failed to successfully set session attribute");

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

// TODO:
- (void) testClearLastSessionsAnalytics {
}

// TODO:
- (void) testClearPersistedSessionAnalytics {
}

@end
