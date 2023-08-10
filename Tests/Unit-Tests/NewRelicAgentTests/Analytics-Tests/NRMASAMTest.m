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
    XCTAssertEqual([decode[@"attribute"] floatValue], 1.5, @"Value of attribute stored is not 1.5");
}

- (void)testMaxAttributeCount {
    // Given
    NRMASAM *sut = [NRMASAM new];
    
    // When
    // Add attributes up to the limit
    for(int i = 0; i < 128; i++) {
        NSString *attributeName = [NSString stringWithFormat:@"attribute %d", i];
        XCTAssertTrue([sut setSessionAttribute:attributeName value:@(i)], @"Failed to add session attribute");
    }
    
    // Then
    XCTAssertFalse([sut setSessionAttribute:@"attribute128" value:@(128)], @"Allowed to add too many attributes");
}

-(void) testRemoveAttribute {
    // Given
    NRMASAM *sut = [NRMASAM new];
    NSError *error = nil;


    // When
    for(int i = 0; i < 3; i++) {
        NSString *attributeName = [NSString stringWithFormat:@"attribute %d", i];
        XCTAssertTrue([sut setSessionAttribute:attributeName value:@(i)], @"Failed to add session attribute");
    }

    // Then
    NSString *attributeJSONString = [sut getSessionAttributeJSONStringWithError: &error];
    NSDictionary *decode = [NSJSONSerialization JSONObjectWithData:[attributeJSONString
                                                               dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:&error];
    XCTAssertEqual([decode count], 3, @"The correct number of attributes are not stored");

    XCTAssertTrue([sut removeSessionAttributeNamed:@"attribute 1"]);
    
    NSString *removedJSON = [sut getSessionAttributeJSONStringWithError:&error];
    NSDictionary *removeDecode = [NSJSONSerialization JSONObjectWithData:[removedJSON dataUsingEncoding:NSUTF8StringEncoding]
                                                                 options:0
                                                                   error:&error];
    
    XCTAssertNil(removeDecode[@"attribute 1"], "@The correct attribute was not removed.");
    XCTAssertNotNil(removeDecode[@"attribute 0"], @"An incorrect attribute was removed");
    XCTAssertNotNil(removeDecode[@"attribute 2"], @"An incorrect attribute was removed");
}

- (void) testRemoveAttributeThatDoesNotExistFails {
    // Given
    NRMASAM *sut = [NRMASAM new];
    NSError *error = nil;


    // When
    [sut setSessionAttribute:@"attribute1" value:@"A Value"];

    // Then
    XCTAssertFalse([sut removeSessionAttributeNamed:@"ThisDoesNotExist"], @"Did not fail when removing a non-existent attribute");
}

- (void)testRemoveAllAttributes {
    // Given
    NRMASAM *sut = [NRMASAM new];
    NSError *error = nil;

    
    // When
    for(int i = 0; i < 3; i++) {
        NSString *attributeName = [NSString stringWithFormat:@"attribute %d", i];
        XCTAssertTrue([sut setSessionAttribute:attributeName value:@(i)], @"Failed to add session attribute");
    }
    
    // Then
    NSString *attributeJSONString = [sut getSessionAttributeJSONStringWithError: &error];
    NSDictionary *decode = [NSJSONSerialization JSONObjectWithData:[attributeJSONString
                                                               dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:&error];
    XCTAssertEqual([decode count], 3, @"The correct number of attributes are not stored");
    
    [sut removeAllSessionAttributes];
    NSString *emptiedJSON = [sut getSessionAttributeJSONStringWithError:&error];
    NSDictionary *emptiedDecode = [NSJSONSerialization JSONObjectWithData:[emptiedJSON dataUsingEncoding:NSUTF8StringEncoding]
                                                                  options:0 error:&error];
    XCTAssertEqual([emptiedDecode count], 0, @"Attributes not emptied");
}

@end
