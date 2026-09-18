//
// Created by Bryce Buchanan on 6/15/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_HEXPUBLISHER_HPP
#define LIBMOBILEAGENT_HEXPUBLISHER_HPP

#include <Hex/HexContext.hpp>
#include <functional>

namespace NewRelic {
    namespace Hex {
        class HexPublisher {

        public:
            virtual void publish(std::shared_ptr<HexContext> const& context);

            // Publish a persisted report identified by reportId (its on-disk path) and
            // report the outcome via onComplete: true means "remove the persisted report"
            // (the upload was confirmed, OR it permanently gave up after the retry limit),
            // false means "keep it" for a later retry. reportId is also used as a stable
            // de-dupe / idempotency identifier so the collector can drop a report that was
            // already delivered in a previous session. The default implementation has no
            // upload result to report and simply completes with remove=true after publishing.
            virtual void publish(std::shared_ptr<HexContext> const& context,
                                 const std::string& reportId,
                                 std::function<void(bool shouldRemove)> onComplete);

            std::string lastPublishedFile();

            explicit HexPublisher(const char* storePath);

            virtual ~HexPublisher() = default;

        protected:
            std::vector<HexContext> reports;

            std::string generateFilename();

            std::string writeBytesToStore(uint8_t* bytes,
                                          size_t length);

            std::string storePath = ".";
            std::string filename = "";
        private:
            static const char* FILE_BASE;
            static const char* FILE_EXTENSION;
        };
    }
}

#endif //LIBMOBILEAGENT_HEXPUBLISHER_HPP
