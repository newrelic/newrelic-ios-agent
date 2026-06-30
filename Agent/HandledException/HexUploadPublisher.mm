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
            // Shared process-wide uploader — its background NSURLSession is a singleton
            // (one per identifier per process). Retain our reference; the shared instance
            // also keeps itself alive.
            uploader->wrapper = [[NRMAHexUploader sharedUploaderWithHost:[NSString stringWithUTF8String:collectorAddress]
                                                       applicationToken:[NSString stringWithUTF8String:appToken]
                                                     applicationVersion:[NSString stringWithUTF8String:appVersion]] retain];
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

        void HexUploadPublisher::retry(){
            [uploader->wrapper retryFailedTasks];
        }

        HexUploadPublisher::~HexUploadPublisher() {
            // The uploader is a shared singleton with a process-wide background session — do
            // NOT invalidate it (that would cancel in-flight background uploads). Just release
            // our retained reference.
            [uploader->wrapper release];
            delete uploader;
        }

        UploaderImpl* HexUploadPublisher::uploaderImpl() {
                return uploader;
        }
    }
}
