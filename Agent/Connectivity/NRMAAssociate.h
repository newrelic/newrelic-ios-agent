//
//  NSObject+NRMASetAssociatedObject.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/6/18.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMAAssociate : NSObject
+ (void)attach:(_Nullable id)value
            to:(_Nonnull id)object
          with:(NSString*)key;
+ (_Nullable id)retrieveFrom:(_Nonnull id)object with:(NSString*)key;
+ (void)removeFrom:(_Nonnull id)object with:(NSString*)key;
@end
