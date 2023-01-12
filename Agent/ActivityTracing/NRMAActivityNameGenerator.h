//
//  NRMAActivityNameGenerator.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/30/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface NRMAActivityNameGenerator : NSObject
+ (NSString*) generateActivityNameFromClass:(Class)cls selector:(SEL)selector;
@end
