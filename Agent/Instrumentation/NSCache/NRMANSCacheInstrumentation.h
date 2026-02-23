//
//  NRMANSCacheInstrumentation.h
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Block type the caller provides to map an NSCache key to the URL the cached
/// object represents.  Return nil for keys you do not want tracked.
typedef NSURL * _Nullable (^NRCacheURLProvider)(id _Nonnull key);

/// Immutable snapshot of a single cache event recorded by the instrumentation.
/// Keys present on every event:
///   @"url"        – NSString, absolute URL string
///   @"cacheType"  – NSString, always @"NSCache"
///   @"key"        – NSString, -description of the NSCache key
/// Lookup events also carry:
///   @"hit"        – NSNumber(BOOL), YES if the object was found
/// Store events also carry:
///   @"stored"     – NSNumber(BOOL), always YES
typedef NSDictionary<NSString *, id> NRMACacheEvent;

/*******************************************************************************
 * NRMANSCacheInstrumentation
 *
 * Instruments NSCache by swizzling -objectForKey:, -setObject:forKey:, and
 * -setObject:forKey:cost: globally once at agent startup.  Only caches that
 * have been registered via +registerCache:withURLProvider: are tracked; all
 * other NSCache instances pass through with zero overhead beyond a single
 * weak-table lookup.
 *
 * Events are written to an in-process log queryable via +recordedEvents,
 * +hitCount, +missCount, and +storeCount.
 *
 * A live reverse index (URL → cache + key) is maintained as objects are stored
 * and is used by +hasCachedObjectForURL: to let other instrumentation layers
 * (e.g. NRMAURLSessionOverride) ask whether a given URL is currently held in
 * any registered NSCache — without enumerating NSCache keys.
 *******************************************************************************/
@interface NRMANSCacheInstrumentation : NSObject

// ---------------------------------------------------------------------------
#pragma mark - Instrumentation lifecycle
// ---------------------------------------------------------------------------

/// Install global NSCache swizzles.  Called once by the agent at startup inside
/// -initializeInstrumentation.  Safe to call multiple times (dispatch_once guard).
+ (void)beginInstrumentation;

/// Restore original NSCache implementations, clear the event log, and discard
/// the reverse URL index.
+ (void)deinstrument;

// ---------------------------------------------------------------------------
#pragma mark - Cache registration
// ---------------------------------------------------------------------------

/// Register @p cache for tracking.  The @p urlProvider block is copied and
/// stored in a weak-keyed map so the cache can be collected normally without
/// any manual deregistration.
///
/// Must be called after the agent has started.  Safe to call from any thread.
+ (void)registerCache:(NSCache *)cache
      withURLProvider:(NRCacheURLProvider)urlProvider;

// ---------------------------------------------------------------------------
#pragma mark - Live reverse lookup
// ---------------------------------------------------------------------------

/// Returns YES if any registered NSCache currently holds an object for @p url.
///
/// The check is a live -objectForKey: call routed through the original (pre-swizzle)
/// IMP so it never generates a spurious entry in the event log.
///
/// Called by NRMAURLSessionOverride's NRMA__markPreflightCacheHit so that
/// URLSession tasks can be tagged as NSCache-backed when the same URL was
/// previously stored in a registered NSCache.
+ (BOOL)hasCachedObjectForURL:(NSURL *)url;

// ---------------------------------------------------------------------------
#pragma mark - In-process event log
// ---------------------------------------------------------------------------

/// Returns a snapshot of all events recorded since the last +clearRecordedEvents.
/// Thread-safe; returns an immutable copy.
+ (NSArray<NRMACacheEvent *> *)recordedEvents;

/// Number of lookup events where @"hit" == YES.
+ (NSUInteger)hitCount;

/// Number of lookup events where @"hit" == NO.
+ (NSUInteger)missCount;

/// Number of store events (@"stored" == YES).
+ (NSUInteger)storeCount;

/// Remove all recorded events.  Does not affect the live reverse URL index.
/// Call this in -setUp / -tearDown of unit tests.
+ (void)clearRecordedEvents;

@end

NS_ASSUME_NONNULL_END
