//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_HEXCONTROLLER_HPP
#define LIBMOBILEAGENT_HEXCONTROLLER_HPP

#include <flatbuffers/flatbuffers.h>

#include <Hex/HexReport.hpp>
#include <Analytics/AnalyticsController.hpp>
#include <Hex/BooleanAttributes.hpp>
#include <Hex/LongAttributes.hpp>
#include <Hex/StringAttributes.hpp>
#include <Hex/DoubleAttributes.hpp>
#include <Hex/Library.hpp>
#include <Hex/Thread.hpp>
#include <Hex/HexPublisher.hpp>
#include <Hex/LibraryController.hpp>
#include <Hex/HexReport.hpp>
#include <Hex/HexStore.hpp>
#include <Hex/HexReportContext.hpp>

namespace NewRelic {
    namespace Hex {
        class HexController {
        public:
            HexController(std::shared_ptr<const AnalyticsController>& analytics,
                          std::shared_ptr<Report::AppInfo> appInfo,
                          HexPublisher* publisher,
                          std::shared_ptr<HexStore>& store,
                          const char* sessionId);

            HexController(std::shared_ptr<const AnalyticsController>&& analytics,
                          std::shared_ptr<Report::AppInfo> appInfo,
                          HexPublisher* publisher,
                          std::shared_ptr<HexStore>& store,
                          const char* sessionId);

            void submit(std::shared_ptr<Report::HexReport> report);

            void publish();

            void setSessionId(const char* sessionId);

            std::shared_ptr<Report::HexReport> createReport(uint64_t epochMs,
                                                            const char* message,
                                                            const char* name,
                                                            const std::map <std::string, std::shared_ptr<AttributeBase>> attributesJson,
                                                            std::vector<std::shared_ptr<Report::Thread>> threads);

            std::shared_ptr<Report::HexReport> createReport(uint64_t epochMs,
                                                            const char* message,
                                                            const char* name,
                                                            std::vector<std::shared_ptr<Report::Thread>> threads);

            virtual ~HexController() = default;

        protected:
            std::shared_ptr<HexReportContext> detachKeyContext();

        private:
            std::shared_ptr<const NewRelic::AnalyticsController> _analytics;
            std::shared_ptr<Report::AppInfo> _applicationInfo;
            HexPublisher* _publisher;
            std::shared_ptr<HexStore>& _store;
            std::string _sessionId;
            mutable std::mutex _keyContextMutex;
            std::shared_ptr<HexReportContext> _keyContext;
        };
    }
}


#endif //LIBMOBILEAGENT_HEXCONTROLLER_HPP
