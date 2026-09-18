//
//  NSObject+NRMAAssociatedObject.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 10/29/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>


void NRMA_pushActingClass(id self, NSString* selector, Class cls);
Class NRMA_popActingClass(id self,NSString* selector);
Class NRMA_actingClass(id self, NSString* selector);
NSMutableArray* NRMA_actingClassArray(id self, NSString* selector);

// Per-thread re-entrancy depth for a given (self, selector). Used to detect
// non-advancing recursion where a [super _cmd] dispatch re-enters the same
// instrumented method on the same object instead of moving up the class
// hierarchy (e.g. Xamarin/MAUI's xamarin_dyn_objc_msgSendSuper trampoline).
// NRMA_enterSelector returns the new depth after incrementing;
// NRMA_exitSelector returns the new depth after decrementing.
NSInteger NRMA_enterSelector(id self, NSString* selector);
NSInteger NRMA_exitSelector(id self, NSString* selector);
