//
//  NRMAHexUploader.h
//  NewRelic
//
//  Created by Bryce Buchanan on 7/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//



#import "NRMAConnection.h"

/*
 * This class manages the upload and retry of binary data to the specified endpoint
 * It is currently used in tandem with the HexUploadPublisher, which is a C++ class passed to the libMobileAgent to
 * manage Hex Report publication.
 *
 * This uploader manages the in-flight upload + retry of reports in memory. Reports are
 * persisted on disk by the HexStore; sendData:reportId:completion: reports the terminal
 * upload outcome back through `completion` so the store can delete a report only after
 * its upload is confirmed (and keep it for retry / next launch otherwise).
 *
 * To replace this object in use look to the HExUploadPublisher where this NRMAHexUploader is injected as a PIMPL
 * object.
 */

@interface NRMAHexUploader : NRMAConnection<NSURLSessionDelegate, NSURLSessionDataDelegate>

- (instancetype) initWithHost:(NSString*)host;

- (void) sendData:(NSData*)data;

// Uploads a persisted report identified by `reportId` (its on-disk path). `completion`
// is invoked exactly once with shouldRemove=YES when the persisted report should be
// deleted (upload confirmed, an oversized payload, or the cross-launch retry budget
// keyed by `reportId` was exhausted), or shouldRemove=NO to keep it for a later attempt.
// `completion` may be nil.
- (void) sendData:(NSData*)data reportId:(NSString*)reportId completion:(void(^)(BOOL shouldRemove))completion;

- (void) retryFailedTasks;

- (void) invalidate;

@end
