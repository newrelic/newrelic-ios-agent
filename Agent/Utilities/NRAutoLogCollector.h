//
//  NRAutoLogCollector.h
//  Agent
//
//  Created by Mike Bruin on 10/9/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRAutoLogCollector : NSObject {


}

+ (void) redirectStandardOutputAndError;
+ (void) restoreStandardOutputAndError;
+ (void) readAndParseLogFile;

@end
