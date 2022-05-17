//
//  NRMAURLTransformerTests.m
//  Agent
//
//  Created by Steve Malsam on 5/17/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "NRMAURLTransformer.h"


@interface NRMAURLTransformerTests : XCTestCase

@property(strong) NSURL* appURL;

@end

@implementation NRMAURLTransformerTests

- (void)setUp {
    [super setUp];
    
    _appURL = [NSURL URLWithString: @"https://httpstat.us/200"];
}

- (void)testSingleRuleApplies {
    // given
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"^http(s{0,1})://(http).*/(\\d)\\d*" : @"https://httpbin.org/status/418"
    };
    
    NRMAURLTransformer *sut = [[NRMAURLTransformer alloc] initWithRegexRules: regexs];
    
    // when
    NSURL *result = [sut transformURL:self.appURL];
    
    // then
    XCTAssertEqualObjects(result.absoluteString, @"https://httpbin.org/status/418");
}

- (void)testOriginalURLIsReturnedIfNoMatch {
    // given
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"hello" : @"https://httpbin.org/status/418"
    };
    
    NRMAURLTransformer *sut = [[NRMAURLTransformer alloc] initWithRegexRules: regexs];
    
    // when
    NSURL *result = [sut transformURL:self.appURL];
    
    // then
    XCTAssertEqualObjects(result.absoluteString, self.appURL.absoluteString);
}

- (void)testReplacementWithToken {
    // given
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"/securities-accounts/[^\\/]*/security-orders/" : @"/securities-accounts/:securitiesAccountId/security-orders"
    };
    
    NSURL *securitiesURL = [NSURL URLWithString:@"https://mybrokerage.org/securities-accounts/678/security-orders/"];
    
    NRMAURLTransformer *sut = [[NRMAURLTransformer alloc] initWithRegexRules: regexs];
    
    // when
    NSURL *result = [sut transformURL:securitiesURL];
    
    // then
    XCTAssertEqualObjects(result.absoluteString, @"https://mybrokerage.org/securities-accounts/:securitiesAccountId/security-orders");
}

- (void)testMultipleReplacements {
    // given
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"/securities-accounts/[^\\/]*/security-orders" : @"/securities-accounts/:securitiesAccountId/security-orders",
       @"/security-portfolios/\\d{10}.{2}" : @"/security-portfolios/:portfolioId"
    };
    
    NSURL *securitiesURL = [NSURL URLWithString:@"https://mybrokerage.org/securities-accounts/678/security-orders/security-portfolios/1234567890w2"];
    
    NRMAURLTransformer *sut = [[NRMAURLTransformer alloc] initWithRegexRules: regexs];
    
    // when
    NSURL *result = [sut transformURL:securitiesURL];
    
    // then
    XCTAssertEqualObjects(result.absoluteString, @"https://mybrokerage.org/securities-accounts/:securitiesAccountId/security-orders/security-portfolios/:portfolioId");
}

- (void)testOneRegexWithMultipleParts {
    // given
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"/payments/direct-debit-transfer/partners/[^\\/]*/direct-debit-transfers/[^\\/]*/validation" : @"/payments/direct-debit-transfer/partners/:partnerId/direct-debit-transfers/:transactionId/validation"
    };
    
    NSURL *securitiesURL = [NSURL URLWithString:@"https://mybrokerage.org/payments/direct-debit-transfer/partners/123/direct-debit-transfers/456789/validation"];
    
    NRMAURLTransformer *sut = [[NRMAURLTransformer alloc] initWithRegexRules: regexs];
    
    // when
    NSURL *result = [sut transformURL:securitiesURL];
    
    // then
    XCTAssertEqualObjects(result.absoluteString, @"https://mybrokerage.org/payments/direct-debit-transfer/partners/:partnerId/direct-debit-transfers/:transactionId/validation");
}

@end
