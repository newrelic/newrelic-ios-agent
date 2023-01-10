//
 //  NRMAApplicationInstrumentationTests.m
 //  Agent_Tests
 //
 //  Created by Anna Huller on 6/9/22.
 //  Copyright © 2023 New Relic. All rights reserved.
 //
 #import <XCTest/XCTest.h>
 #import "NRMAApplicationInstrumentation.h"
 #import "NRMAGestureProcessor.h"
 #import "NRMAGestureRecognizerInstrumentation.h"

 #import "NRMAWKWebViewInstrumentation.h"
 #import "NRMAWKWebViewNavigationDelegate.h"

 @interface InstrumentationTests : XCTestCase

 @end

 @implementation InstrumentationTests

 -(void) testInstrumentation {

     XCTAssertFalse([NRMAApplicationInstrumentation deinstrumentUIApplication], @"should not be able to deinstrument without instrumenting first");
     XCTAssertTrue([NRMAApplicationInstrumentation instrumentUIApplication], @"should successfully instrument");
     XCTAssertFalse([NRMAApplicationInstrumentation instrumentUIApplication], @"should not instrument already instrumented application");
     XCTAssertTrue([NRMAApplicationInstrumentation deinstrumentUIApplication], @"should successfully deinstrument");
 }


 -(void) testGestureRecognizerInstrumentation {
     XCTAssertFalse([NRMAGestureRecognizerInstrumentation deinstrumentUIGestureRecognizer]);
     XCTAssertTrue([NRMAGestureRecognizerInstrumentation instrumentUIGestureRecognizer]);
     XCTAssertFalse([NRMAGestureRecognizerInstrumentation instrumentUIGestureRecognizer]);
 }

 -(void) testWebViewInstrumentationNoThrow {
     XCTAssertNoThrow([NRMAWKWebViewInstrumentation deinstrument], @"shouldn't throw even when called before instrument");
     XCTAssertNoThrow([NRMAWKWebViewInstrumentation instrument], @"normal case should not throw");
     XCTAssertNoThrow([NRMAWKWebViewInstrumentation deinstrument], @"normal case should not throw");

 }

 @end
