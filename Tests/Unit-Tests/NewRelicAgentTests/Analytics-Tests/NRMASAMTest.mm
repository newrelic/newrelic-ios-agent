//
//  NRMASAMTest.mm
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMASAM.h"

@interface NRMASAMTest : XCTestCase
{
}
@end

@implementation NRMASAMTest

- (void) testSetSessionAttribute {
    NRMASAM *manager = [NRMASAM new];
    XCTAssertTrue([manager setSessionAttribute:@"blarg" value:@"blurg" persistent:true], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg"] isEqualToString:@"blurg"]);
}

- (void) testSetNRSessionAttribute {
    NRMASAM *manager = [NRMASAM new];
    XCTAssertTrue([manager setNRSessionAttribute:@"blarg" value:@"blurg"], @"Failed to successfully set session attribute");

    NSString* attributes = [manager sessionAttributeJSONString];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"blarg"] isEqualToString:@"blurg"]);
}

- (void) testIncrementSessionAttribute {
    NRMASAM *manager = [NRMASAM new];
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
    NRMASAM *manager = [NRMASAM new];
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
    NRMASAM *manager = [NRMASAM new];
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
    NRMASAM *manager = [NRMASAM new];
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
    NRMASAM *manager = [NRMASAM new];
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
