//
//  Created by Saxon D'Aubin on 5/23/12.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Alias prefix NRMA__generateAndSwizzleMethod stores a method's original
// implementation under, once instrumented. Shared with NRMAMethodProfiler.m,
// which installs the aliases this file's NRMAUninstrumentedSelector looks up.
#define NRMAMethodStoragePrefix @"NRMAMethodOverride_"

/*!
 Returns the selector that reaches the real, unswizzled implementation of
 `selector` on class `c`, bypassing any tracing/instrumentation wrapper the
 agent has installed via NRMASwapOrReplaceClassMethod / NRMASwapOrReplaceInstanceMethod.
 If `selector` was never swizzled on `c` (or class `c` is nil), returns
 `selector` itself unchanged.

 Internal agent code that must call a method the agent also instruments for
 app-interaction tracing (e.g. NSJSONSerialization) should look up and invoke
 through this selector instead of calling `selector` directly -- otherwise the
 agent's own usage re-enters app-interaction tracing on every call, which is
 both semantically wrong (it isn't app activity) and, at the call volumes the
 agent's own logging/serialization produce, can overwhelm the tracing system.
 */
SEL NRMAUninstrumentedSelector(Class c, SEL selector);

/*
    replaces the implementation of Method for class c SEL selector with newImplementation.
    this works for both class and instance methods.
    returns the original implementation
 */
void* NRMASwapImplementations(Class c, SEL selector, IMP newImplementation);
/*
 Replaces the implementation of the given selector with the new implementation and returns a 
 pointer to the original implementation, or nil if it was not present.
 
 This method is used to replace methods on known classes.
 */

void NRMASwapOrReplaceClassMethod(Class c, SEL originalSelector, SEL newSelector);
void* NRMAReplaceInstanceMethod(Class c, SEL selector, IMP newImplementation);
/*
 Replaces the implementation of the given selector with the new implementation and returns a 
 pointer to the original implementation, or nil if it was not present.
 
 This method is used to replace class methods on known classes.
 */
void* NRMAReplaceClassMethod(Class c, SEL selector, IMP newImplementation);
/*
 If the new method is unknown by the class c, we add it to c, and replace the
 implementation of the orig method by the new implementation.
 If it's known by the class c, we just exchange the implementation.
 */
void NRMASwapOrReplaceInstanceMethod(Class c, SEL originalSelector, SEL newSelector);

/*!
 @method NRMASwizzleOrAddMethod
 
 @abstract
 Swaps one method implementation with another if this instance
 responds to the original selector.  Otherwise, the method implementation is
 added to the class using the original selector.
 
 Unlike the two above methods, this method is used to swap methods on classes that are not 
 known until runtime, usually protocol implementations.
 
 
 @param  origSelector     The selector for the original method
 newSelector      The selector for the method to be swapped
 
 YES         if the swizzle was successful
 
 NO            
 */
BOOL NRMASwizzleOrAddMethod(id self, SEL origSelector, SEL newSelector, IMP theImplementation);
