//
// Created by Bryce Buchanan on 7/7/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#include "HexUploadPublisher.hpp"
#import <Foundation/Foundation.h>
#import "NRMAHexUploader.h"
#import "NRLogger.h"

namespace NewRelic {
    namespace Hex {

        struct UploaderImpl {
            NRMAHexUploader* wrapper;
        };

        HexUploadPublisher::HexUploadPublisher(const char* storePath, const char* appToken, const char* appVersion, const char* collectorAddress)
                : HexPublisher::HexPublisher(storePath),
                  uploader(new UploaderImpl) {
            // Here we handle the collector address param.
            uploader->wrapper = [[NRMAHexUploader alloc] initWithHost:[NSString stringWithUTF8String:collectorAddress]];
            uploader->wrapper.applicationToken = [NSString stringWithUTF8String:appToken];
            uploader->wrapper.applicationVersion = [NSString stringWithUTF8String:appVersion];
        }

        void HexUploadPublisher::publish(std::shared_ptr<NewRelic::Hex::HexContext>const& context) {

            auto buf = context->getBuilder()->GetBufferPointer();
            auto size = context->getBuilder()->GetSize();

            @autoreleasepool {
                NSData* report = [NSData dataWithBytes:buf
                                                length:size];

                [uploader->wrapper sendData:report];
            }
        }

        void HexUploadPublisher::publish(std::shared_ptr<NewRelic::Hex::HexContext>const& context,
                                         const std::string& reportId,
                                         std::function<void(bool shouldRemove)> onComplete) {

            auto buf = context->getBuilder()->GetBufferPointer();
            auto size = context->getBuilder()->GetSize();

            @autoreleasepool {
                NSData* report = [NSData dataWithBytes:buf
                                                length:size];
                NSString* nsReportId = [NSString stringWithUTF8String:reportId.c_str()];

                NRLOG_AGENT_VERBOSE(@"[HexDelete] HexUploadPublisher::publish: bridging upload for report %@ (%lu bytes)",
                                    nsReportId, (unsigned long)report.length);

                // Bridge the C++ completion to an Obj-C block the uploader fires once
                // the upload terminally resolves. shouldRemove==YES => delete the
                // persisted report (confirmed, or gave up after the retry limit).
                __block std::function<void(bool)> cb = onComplete;
                [uploader->wrapper sendData:report
                                   reportId:nsReportId
                                 completion:^(BOOL shouldRemove) {
                    NRLOG_AGENT_VERBOSE(@"[HexDelete] HexUploadPublisher: completion for report %@ shouldRemove=%@",
                                        nsReportId, shouldRemove ? @"YES" : @"NO");
                    if (cb) {
                        cb(shouldRemove);
                    } else {
                        NRLOG_AGENT_WARNING(@"[HexDelete] HexUploadPublisher: completion fired MORE THAN ONCE "
                                            @"for report %@ (ignored) — store already resolved", nsReportId);
                    }
                    cb = nullptr;
                }];
            }
        }

        void HexUploadPublisher::retry(){
            [uploader->wrapper retryFailedTasks];
        }

        HexUploadPublisher::~HexUploadPublisher() {
            [uploader->wrapper invalidate];
            [uploader->wrapper release];
            delete uploader;
        }

        UploaderImpl* HexUploadPublisher::uploaderImpl() {
                return uploader;
        }
    }
}
