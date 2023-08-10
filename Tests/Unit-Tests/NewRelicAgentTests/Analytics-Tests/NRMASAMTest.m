//
//  NRMASAMTest.m
//  Agent_Tests
//
//  Created by Steve Malsam on 8/10/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NRMASAM.h"

@interface NRMASAMTest : XCTestCase

@end

@implementation NRMASAMTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testRetrieveSessionJSON {
    // Given
    NRMASAM *sut = [NRMASAM new];
    NSError *error = nil;
    
    // When
    [sut setSessionAttribute:@"attribute" value:@(1.5)];
    NSString *attributeJSONString = [sut getSessionAttributeJSONStringWithError: &error];
    
    // Then
    NSDictionary *decode = [NSJSONSerialization JSONObjectWithData:[attributeJSONString
                                                               dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:&error];
    XCTAssertNotNil(decode[@"attribute"]);
    XCTAssertEqual([decode[@"attribute"] floatValue], 1.5);
}

//- (void)testAddFloatAttribute {
//    // Given
//    NRMASAM *sut = [NRMASAM new];
//
//    // When
//    [sut setSessionAttribute:@"attribute" value:1.0];
//
//    // Then
//
//}

@end
