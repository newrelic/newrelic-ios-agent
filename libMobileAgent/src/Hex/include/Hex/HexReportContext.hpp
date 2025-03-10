//
// Created by Bryce Buchanan on 9/22/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_HEXREPORTCONTEXT_HPP
#define LIBMOBILEAGENT_HEXREPORTCONTEXT_HPP

#include <Hex/HexContext.hpp>
#include <Hex/HexPublisher.hpp>

namespace NewRelic {
    namespace Hex {
        class HexReportContext : public HexContext, public std::enable_shared_from_this<HexReportContext> {

        public:
            HexReportContext(const std::shared_ptr<Report::AppInfo>& applicationInfo,
                             const AttributeValidator& attributeValidator,
                             HexPublisher* publisher);

            virtual void finalize();

            std::shared_ptr<Report::HexReport> createReport(std::shared_ptr<Report::HandledException> exception);

            void insert(std::shared_ptr<Report::HexReport> report);

            unsigned long reports();

        private:
            mutable std::mutex reportMutex;
            std::vector<std::shared_ptr<Report::HexReport>> reportList;
            const AttributeValidator& _attributeValidator;
            const std::shared_ptr<Report::AppInfo>& _applicationInfo;
            HexPublisher* _publisher;
        };
    }
}


#endif //LIBMOBILEAGENT_HEXREPORTCONTEXT_HPP
