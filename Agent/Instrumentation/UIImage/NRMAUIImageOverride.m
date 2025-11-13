//
//  NRMAUIImageOverride.m
//  Agent
//
//  Created by Mike Bruin on 1/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMAUIImageOverride.h"
#import "NRMAMethodSwizzling.h"
#import "NRLogger.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <NewRelic/NewRelic-Swift.h>

static IMP NRMAOriginal__initWithData;
static IMP NRMAOriginal__initWithData_scale;

// Global registry to map data hashes to URLs
static NSMapTable *dataHashToURLMap;
static NSLock *registryLock;

// Flag to prevent double swizzling
static BOOL isSwizzled = NO;

// Forward declarations
UIImage* NRMAOverride__initWithData(UIImage* self, SEL _cmd, NSData* data);
UIImage* NRMAOverride__initWithData_scale(UIImage* self, SEL _cmd, NSData* data, CGFloat scale);
NSString* NRMA_HashForData(NSData* data);

@implementation NRMAUIImageOverride

+ (void)beginInstrumentation {
    // Prevent double swizzling
    if (isSwizzled) {
        NRLOG_AGENT_DEBUG(@"NRMAUIImageOverride - Already instrumented, skipping swizzling");
        return;
    }
    
    Class clazz = [UIImage class];
    
    // Initialize the global registry and lock
    if (dataHashToURLMap == nil) {
        dataHashToURLMap = [NSMapTable strongToStrongObjectsMapTable];
        registryLock = [[NSLock alloc] init];
    }
    
    if (clazz) {
        // Swizzle initWithData:
        NRMAOriginal__initWithData = NRMASwapImplementations(clazz,
            @selector(initWithData:),
            (IMP)NRMAOverride__initWithData);
        
        // Swizzle initWithData:scale:
        NRMAOriginal__initWithData_scale = NRMASwapImplementations(clazz,
            @selector(initWithData:scale:),
            (IMP)NRMAOverride__initWithData_scale);
        
        // Mark as swizzled
        isSwizzled = YES;
        NRLOG_AGENT_DEBUG(@"NRMAUIImageOverride - Instrumentation completed successfully");
    }
}

// Public method to register a URL for NSData
+ (void)registerURL:(NSURL*)url forData:(NSData*)data {
    if (url == nil || data == nil) return;
    
    // Check if data is actually an image before storing it
    if (![self isImageData:data]) {
        //NRLOG_AGENT_DEBUG(@"NRMAUIImageOverride - Skipping non-image data for URL: %@", url);
        return;
    }
    
    NSString *hash = NRMA_HashForData(data);
    [registryLock lock];
    
    [dataHashToURLMap setObject:url forKey:hash];
    
    [registryLock unlock];
    
    NRLOG_AGENT_DEBUG(@"NRMAUIImageOverride - Registered image URL for replay: %@ (map size: %lu)", url, (unsigned long)dataHashToURLMap.count);
}

// Helper method to check if NSData contains image data
+ (BOOL)isImageData:(NSData*)data {
    if (data == nil || data.length < 12) {
        return NO;
    }
    
    // Check common image format signatures (magic numbers)
    const unsigned char *bytes = (const unsigned char *)data.bytes;
    
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (data.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
        return YES;
    }
    
    // JPEG: FF D8 FF
    if (data.length >= 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return YES;
    }
    
    return NO;
}

+ (void)deinstrument {
    Class clazz = [UIImage class];
    
    if (clazz) {
        if (NRMAOriginal__initWithData != nil) {
            NRMASwapImplementations(clazz, @selector(initWithData:), (IMP)NRMAOriginal__initWithData);
            NRMAOriginal__initWithData = nil;
        }
        
        if (NRMAOriginal__initWithData_scale != nil) {
            NRMASwapImplementations(clazz, @selector(initWithData:scale:), (IMP)NRMAOriginal__initWithData_scale);
            NRMAOriginal__initWithData_scale = nil;
        }
    }
    
    // Clean up registry
    [registryLock lock];
    [dataHashToURLMap removeAllObjects];
    [registryLock unlock];
    
    // Reset the swizzled flag
    isSwizzled = NO;
}

@end

// Swizzled implementation for initWithData:
UIImage* NRMAOverride__initWithData(UIImage* self, SEL _cmd, NSData* data) {
    if (NRMAOriginal__initWithData == nil || data == nil) {
        return nil;
    }
    
    NSString *hash = NRMA_HashForData(data);
    [registryLock lock];
    NSURL* url = [dataHashToURLMap objectForKey:hash];
    
    // Remove the entry after retrieving it (automatic cleanup after use)
    if (url != nil) {
        [dataHashToURLMap removeObjectForKey:hash];
    }
    
    [registryLock unlock];
    
    // Call original implementation
    UIImage* image = ((UIImage*(*)(id, SEL, NSData*))NRMAOriginal__initWithData)(self, _cmd, data);
    
    if (image != nil && url != nil) {
        // Attach the URL to the newly created UIImage
        image.NRSessionReplayImageURL = url;
        NRLOG_AGENT_DEBUG(@"NRMAOverride__initWithData - Successfully attached URL to image: %@", url);
    }
    
    return image;
}

// Swizzled implementation for initWithData:scale:
UIImage* NRMAOverride__initWithData_scale(UIImage* self, SEL _cmd, NSData* data, CGFloat scale) {
    if (NRMAOriginal__initWithData_scale == nil || data == nil) {
        return nil;
    }
    
    NSString *hash = NRMA_HashForData(data);
    [registryLock lock];
    NSURL* url = [dataHashToURLMap objectForKey:hash];
    
    // Remove the entry after retrieving it (automatic cleanup after use)
    if (url != nil) {
        [dataHashToURLMap removeObjectForKey:hash];
    }
    
    [registryLock unlock];
    
    // Call original implementation
    UIImage* image = ((UIImage*(*)(id, SEL, NSData*, CGFloat))NRMAOriginal__initWithData_scale)(self, _cmd, data, scale);
    
    if (image != nil && url != nil) {
        // Attach the URL to the newly created UIImage
        image.NRSessionReplayImageURL = url;
        NRLOG_AGENT_DEBUG(@"NRMAOverride__initWithData:scale: - Successfully attached URL to image: %@", url);
    }
    
    return image;
}

// Helper function to generate a hash for NSData
NSString* NRMA_HashForData(NSData* data) {
    if (data == nil || data.length == 0) {
        return nil;
    }
    
    // For performance, only hash the first 1KB and last 1KB along with the length
    // This is sufficient to uniquely identify image data in most cases
    NSUInteger length = data.length;
    NSUInteger hashLength = MIN(1024, length);
    
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    
    // Hash the length
    CC_SHA256_Update(&ctx, &length, sizeof(length));
    
    // Hash first chunk
    CC_SHA256_Update(&ctx, data.bytes, (CC_LONG)hashLength);
    
    // If data is large enough, also hash last chunk
    if (length > 2048) {
        const void *lastChunk = data.bytes + (length - hashLength);
        CC_SHA256_Update(&ctx, lastChunk, (CC_LONG)hashLength);
    }
    
    CC_SHA256_Final(hash, &ctx);
    
    // Convert to hex string
    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashString appendFormat:@"%02x", hash[i]];
    }
    
    return hashString;
}

