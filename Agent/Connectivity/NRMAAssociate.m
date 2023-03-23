//
//  NSObject+NRMASetAssociatedObject.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 2/6/18.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAssociate.h"
#import <objc/runtime.h>

@implementation NRMAAssociate

+ (void)attach:(id)value
            to:(_Nonnull id)object
          with:(NSString *)key {
        if (object == nil) return;

        objc_setAssociatedObject(object,
                                 [key cStringUsingEncoding:NSUTF8StringEncoding],
                                 value,
                                 OBJC_ASSOCIATION_RETAIN);

    }

+ (_Nullable id)retrieveFrom:(_Nonnull id)object
              with:(NSString *)key {
    if (object == nil) return nil;

    return objc_getAssociatedObject(object,
                                    [key cStringUsingEncoding:NSUTF8StringEncoding]);
}

+ (void)removeFrom:(_Nonnull id)object
              with:(NSString *)key {
    if (object == nil) return;

    objc_setAssociatedObject(object,
                             [key cStringUsingEncoding:NSUTF8StringEncoding],
                             nil,
                             OBJC_ASSOCIATION_ASSIGN);
}

@end
