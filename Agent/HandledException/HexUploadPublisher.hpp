//
// Created by Bryce Buchanan on 7/7/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#ifndef NEWRELICAGENT_HEXUPLOADPUBLISHER_H
#define NEWRELICAGENT_HEXUPLOADPUBLISHER_H

#include <Hex/HexPublisher.hpp>
#include <functional>
/*
 * Follows the HexPublisher interface for dependency injection into the NewRelic::Hex::HexController
 * This class uses a PIMPL to allow for Obj-c code to be called from C++ allowing access to the high-level networking
 * libraries, e.g. NSURLSession.
 */
namespace NewRelic {
    namespace Hex {

        struct UploaderImpl;

        class HexUploadPublisher : public HexPublisher {
        public:
            HexUploadPublisher(const char* storePath, const char* appToken, const char* appVersion, const char* collectorAddress);
            HexUploadPublisher(const HexUploadPublisher&) = delete;
            virtual void publish(std::shared_ptr<HexContext>const& context);
            // Uploads the report and invokes onComplete(true) when the persisted report
            // should be removed (upload confirmed, HTTP < 400, OR the per-report retry
            // limit was reached), or onComplete(false) to keep it for a later retry.
            // reportId is the persisted file path; its filename is sent as a stable
            // de-dupe identifier and used as the persisted retry-counter key.
            virtual void publish(std::shared_ptr<HexContext>const& context,
                                 const std::string& reportId,
                                 std::function<void(bool shouldRemove)> onComplete);
            virtual ~HexUploadPublisher();
//            void auditFlatBuffer(uint8_t* buf);
            void retry();
        protected:
            UploaderImpl* uploaderImpl(); //testing
        private:
            UploaderImpl* uploader;
        };

    }
}

#endif //NEWRELICAGENT_HEXUPLOADPUBLISHER_H
