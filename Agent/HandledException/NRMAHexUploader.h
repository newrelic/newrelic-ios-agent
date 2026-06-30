//
//  NRMAHexUploader.h
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//



#import "NRMAConnection.h"

/*
 * This class manages the upload and retry of binary data to the specified endpoint.
 * It is currently used in tandem with the HexUploadPublisher, which is a C++ class passed to the libMobileAgent to
 * manage Hex Report publication.
 *
 * Uploads are sent via a default NSURLSession with bounded concurrency. Failed uploads that meet the persist-worthy
 * criteria (offline / network error) are written to NRMAOfflineStorage and re-sent on the next successful upload,
 * ensuring payloads survive transient connectivity loss.
 *
 * To replace this object in use look to the HExUploadPublisher where this NRMAHexUploader is injected as a PIMPL
 * object.
 */

@interface NRMAHexUploader : NRMAConnection<NSURLSessionDelegate, NSURLSessionDataDelegate>

- (instancetype) initWithHost:(NSString*)host;

// Process-wide shared uploader. Keeps a single connection pool and pending queue so
// that uploads from different callers are serialised through a single session.
// Refreshes host/token/version on reuse.
+ (instancetype) sharedUploaderWithHost:(NSString*)host
                       applicationToken:(NSString*)applicationToken
                     applicationVersion:(NSString*)applicationVersion;

- (void) sendData:(NSData*)data;

- (void) retryFailedTasks;

- (void) invalidate;

@end
