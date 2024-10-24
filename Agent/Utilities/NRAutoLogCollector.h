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

+ (BOOL) redirectStandardOutputAndError;
+ (void) restoreStandardOutputAndError;

@end
