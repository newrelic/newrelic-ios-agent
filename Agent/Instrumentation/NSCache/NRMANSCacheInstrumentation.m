//
//  NRMANSCacheInstrumentation.m
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMANSCacheInstrumentation.h"
#import "NRMAMethodSwizzling.h"
#import "NRLogger.h"
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// Registry
//
// NSMapTable with weak keys so registered caches can be collected without
// any manual deregistration from the caller.
// ---------------------------------------------------------------------------
static NSMapTable<NSCache *, NRCacheURLProvider> *_nrCacheRegistry      = nil;
/// Concurrent queue — readers use dispatch_sync, writers use dispatch_barrier_async.
static dispatch_queue_t                           _nrCacheRegistryQueue = nil;

// ---------------------------------------------------------------------------
// Reverse URL index
//
// Populated on every -setObject:forKey:[cost:] call for a registered cache.
// Maps URL absolute string → (NSCache weak ref, NSCache key) so that
// +hasCachedObjectForURL: can perform a live lookup without enumerating keys.
//
// _nrURLCacheIndex uses strong-to-WEAK values so that a deallocated NSCache
// automatically zeroes out, returning nil for +hasCachedObjectForURL: queries.
// ---------------------------------------------------------------------------
static NSMapTable<NSString *, NSCache *>   *_nrURLCacheIndex   = nil;  // URL → cache (weak value)
static NSMutableDictionary<NSString *, id> *_nrURLKeyIndex     = nil;  // URL → cache key
static dispatch_queue_t                     _nrReverseIndexQueue = nil;

// ---------------------------------------------------------------------------
// In-process event log
// ---------------------------------------------------------------------------
static NSMutableArray<NRMACacheEvent *> *_nrEventLog      = nil;
static dispatch_queue_t                  _nrEventLogQueue = nil;

// ---------------------------------------------------------------------------
// Original IMPs saved during swizzle
// ---------------------------------------------------------------------------
static IMP NRMAOriginal__objectForKey        = nil;
static IMP NRMAOriginal__setObjectForKey     = nil;
static IMP NRMAOriginal__setObjectForKeyCost = nil;

// ---------------------------------------------------------------------------
#pragma mark - Internal helpers
// ---------------------------------------------------------------------------

/// Looks up the URL provider registered for @p cache.
/// Returns nil if the cache is not registered (fast path — zero overhead).
static NRCacheURLProvider _nrProviderForCache(NSCache *cache) {
    __block NRCacheURLProvider provider = nil;
    dispatch_sync(_nrCacheRegistryQueue, ^{
        provider = [_nrCacheRegistry objectForKey:cache];
    });
    return provider;
}

/// Records a cache event in the in-process log and, for store events, updates
/// the reverse URL index so +hasCachedObjectForURL: can do live lookups later.
///
/// @param cache   The NSCache instance that fired.  Used only for reverse-index
///                updates on store events; pass nil for lookup events.
static void _nrAppendCacheEvent(NSCache * _Nullable cache, NSURL *url, id key, BOOL isHit, BOOL isStore) {
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:@{
        @"url"       : url.absoluteString ?: @"",
        @"cacheType" : @"NSCache",
        @"key"       : [key description] ?: @"",
    }];

    if (isStore) {
        event[@"stored"] = @YES;
        NRLOG_AGENT_DEBUG(@"[NSCache] store  url=%@", url.absoluteString);

        // Update the reverse URL index so that hasCachedObjectForURL: can later
        // verify live presence of this URL without enumerating all cache keys.
        NSString *urlString = url.absoluteString;
        NSCache *cacheRef   = cache;   // captured strongly for the barrier block,
                                       // held weakly in _nrURLCacheIndex after insertion.
        dispatch_barrier_async(_nrReverseIndexQueue, ^{
            [_nrURLCacheIndex setObject:cacheRef forKey:urlString];
            _nrURLKeyIndex[urlString] = key;
        });
    } else {
        event[@"hit"] = @(isHit);
        NRLOG_AGENT_DEBUG(@"[NSCache] %@  url=%@", isHit ? @"HIT " : @"MISS", url.absoluteString);
    }

    NRMACacheEvent *snapshot = [event copy];
    dispatch_barrier_async(_nrEventLogQueue, ^{
        [_nrEventLog addObject:snapshot];
    });
}

// ---------------------------------------------------------------------------
#pragma mark - Swizzled NSCache implementations
// ---------------------------------------------------------------------------

/// -[NSCache objectForKey:]
id NRMAOverride__objectForKey(NSCache *self, SEL _cmd, id key) {
    id result = ((id(*)(id, SEL, id))NRMAOriginal__objectForKey)(self, _cmd, key);

    if (key == nil) return result;

    NRCacheURLProvider provider = _nrProviderForCache(self);
    if (provider == nil) return result;   // unregistered cache — zero overhead

    NSURL *url = provider(key);
    if (url == nil) return result;        // provider opted out for this key

    _nrAppendCacheEvent(nil, url, key, result != nil, NO);
    return result;
}

/// -[NSCache setObject:forKey:]
void NRMAOverride__setObjectForKey(NSCache *self, SEL _cmd, id obj, id key) {
    ((void(*)(id, SEL, id, id))NRMAOriginal__setObjectForKey)(self, _cmd, obj, key);

    if (key == nil || obj == nil) return;

    NRCacheURLProvider provider = _nrProviderForCache(self);
    if (provider == nil) return;

    NSURL *url = provider(key);
    if (url == nil) return;

    _nrAppendCacheEvent(self, url, key, NO, YES);
}

/// -[NSCache setObject:forKey:cost:]
void NRMAOverride__setObjectForKeyCost(NSCache *self, SEL _cmd, id obj, id key, NSUInteger cost) {
    ((void(*)(id, SEL, id, id, NSUInteger))NRMAOriginal__setObjectForKeyCost)(self, _cmd, obj, key, cost);

    if (key == nil || obj == nil) return;

    NRCacheURLProvider provider = _nrProviderForCache(self);
    if (provider == nil) return;

    NSURL *url = provider(key);
    if (url == nil) return;

    _nrAppendCacheEvent(self, url, key, NO, YES);
}

// ---------------------------------------------------------------------------
#pragma mark - NRMANSCacheInstrumentation
// ---------------------------------------------------------------------------

@implementation NRMANSCacheInstrumentation

+ (void)initialize {
    if (self == [NRMANSCacheInstrumentation class]) {
        _nrCacheRegistry      = [NSMapTable weakToStrongObjectsMapTable];
        _nrCacheRegistryQueue = dispatch_queue_create("com.newrelic.nscache.registry",
                                                      DISPATCH_QUEUE_CONCURRENT);

        _nrURLCacheIndex      = [NSMapTable strongToWeakObjectsMapTable];
        _nrURLKeyIndex        = [NSMutableDictionary dictionary];
        _nrReverseIndexQueue  = dispatch_queue_create("com.newrelic.nscache.reverseindex",
                                                      DISPATCH_QUEUE_CONCURRENT);

        _nrEventLog           = [NSMutableArray array];
        _nrEventLogQueue      = dispatch_queue_create("com.newrelic.nscache.eventlog",
                                                      DISPATCH_QUEUE_CONCURRENT);
    }
}

+ (void)beginInstrumentation {
    NRLOG_AGENT_DEBUG(@"[NSCache] beginInstrumentation: installing swizzles");

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cacheClass = [NSCache class];

        NRMAOriginal__objectForKey =
            NRMASwapImplementations(cacheClass,
                                    @selector(objectForKey:),
                                    (IMP)NRMAOverride__objectForKey);
        NRLOG_AGENT_DEBUG(@"[NSCache] swizzled -objectForKey:");

        NRMAOriginal__setObjectForKey =
            NRMASwapImplementations(cacheClass,
                                    @selector(setObject:forKey:),
                                    (IMP)NRMAOverride__setObjectForKey);
        NRLOG_AGENT_DEBUG(@"[NSCache] swizzled -setObject:forKey:");

        NRMAOriginal__setObjectForKeyCost =
            NRMASwapImplementations(cacheClass,
                                    @selector(setObject:forKey:cost:),
                                    (IMP)NRMAOverride__setObjectForKeyCost);
        NRLOG_AGENT_DEBUG(@"[NSCache] swizzled -setObject:forKey:cost:");
    });
}

+ (void)deinstrument {
    Class cacheClass = [NSCache class];

    if (NRMAOriginal__objectForKey != nil) {
        NRMASwapImplementations(cacheClass,
                                @selector(objectForKey:),
                                (IMP)NRMAOriginal__objectForKey);
        NRMAOriginal__objectForKey = nil;
    }

    if (NRMAOriginal__setObjectForKey != nil) {
        NRMASwapImplementations(cacheClass,
                                @selector(setObject:forKey:),
                                (IMP)NRMAOriginal__setObjectForKey);
        NRMAOriginal__setObjectForKey = nil;
    }

    if (NRMAOriginal__setObjectForKeyCost != nil) {
        NRMASwapImplementations(cacheClass,
                                @selector(setObject:forKey:cost:),
                                (IMP)NRMAOriginal__setObjectForKeyCost);
        NRMAOriginal__setObjectForKeyCost = nil;
    }

    // Discard live state.
    [self clearRecordedEvents];
    dispatch_barrier_async(_nrReverseIndexQueue, ^{
        [_nrURLCacheIndex removeAllObjects];
        [_nrURLKeyIndex   removeAllObjects];
    });

    NRLOG_AGENT_DEBUG(@"[NSCache] deinstrumented");
}

+ (void)registerCache:(NSCache *)cache withURLProvider:(NRCacheURLProvider)urlProvider {
    if (cache == nil || urlProvider == nil) {
        NRLOG_AGENT_DEBUG(@"[NSCache] registerCache: called with nil argument, ignoring");
        return;
    }

    NRCacheURLProvider copied = [urlProvider copy];
    dispatch_barrier_async(_nrCacheRegistryQueue, ^{
        [_nrCacheRegistry setObject:copied forKey:cache];
    });

    NRLOG_AGENT_DEBUG(@"[NSCache] registered cache name=%@ address=%p",
                      cache.name.length ? cache.name : @"(unnamed)", (void *)cache);
}

// ---------------------------------------------------------------------------
#pragma mark - Live reverse lookup
// ---------------------------------------------------------------------------

+ (BOOL)hasCachedObjectForURL:(NSURL *)url {
    if (url == nil) return NO;

    NSString *urlString = url.absoluteString;
    __block NSCache *cache    = nil;
    __block id       cacheKey = nil;

    dispatch_sync(_nrReverseIndexQueue, ^{
        cache    = [_nrURLCacheIndex objectForKey:urlString]; // nil if cache was deallocated
        cacheKey = _nrURLKeyIndex[urlString];
    });

    if (cache == nil || cacheKey == nil) return NO;

    // Bypass the swizzle so this lookup does not generate a spurious event
    // in the in-process log — this is a passive probe, not a real cache access.
    id result = ((id(*)(id, SEL, id))NRMAOriginal__objectForKey)(cache,
                                                                  @selector(objectForKey:),
                                                                  cacheKey);
    NRLOG_AGENT_DEBUG(@"[NSCache] hasCachedObjectForURL: url=%@ → %@",
                      urlString, result ? @"YES (live hit)" : @"NO (evicted or absent)");
    return result != nil;
}

// ---------------------------------------------------------------------------
#pragma mark - In-process event log
// ---------------------------------------------------------------------------

+ (NSArray<NRMACacheEvent *> *)recordedEvents {
    __block NSArray<NRMACacheEvent *> *snapshot = nil;
    dispatch_sync(_nrEventLogQueue, ^{
        snapshot = [_nrEventLog copy];
    });
    return snapshot;
}

+ (NSUInteger)hitCount {
    __block NSUInteger count = 0;
    dispatch_sync(_nrEventLogQueue, ^{
        for (NRMACacheEvent *e in _nrEventLog) {
            if ([e[@"hit"] boolValue]) count++;
        }
    });
    return count;
}

+ (NSUInteger)missCount {
    __block NSUInteger count = 0;
    dispatch_sync(_nrEventLogQueue, ^{
        for (NRMACacheEvent *e in _nrEventLog) {
            if (e[@"hit"] != nil && ![e[@"hit"] boolValue]) count++;
        }
    });
    return count;
}

+ (NSUInteger)storeCount {
    __block NSUInteger count = 0;
    dispatch_sync(_nrEventLogQueue, ^{
        for (NRMACacheEvent *e in _nrEventLog) {
            if ([e[@"stored"] boolValue]) count++;
        }
    });
    return count;
}

+ (void)clearRecordedEvents {
    dispatch_barrier_async(_nrEventLogQueue, ^{
        [_nrEventLog removeAllObjects];
    });
}

@end
