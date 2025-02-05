//
// Created by Bryce Buchanan on 9/22/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "HexReportContext.hpp"
#include <Utilities/libLogger.hpp>
#include "hex-agent-data-bundle_generated.h"
#include "jserror_generated.h"

using namespace NewRelic::Hex;
using namespace com::newrelic::mobile;

HexReportContext::HexReportContext(const std::shared_ptr<Report::AppInfo>& applicationInfo,
                                   const AttributeValidator& attributeValidator,
                                   HexPublisher* publisher)
        : HexContext::HexContext(),
          _attributeValidator(attributeValidator),
          _applicationInfo(applicationInfo),
          _publisher(publisher){}

void HexReportContext::finalize() {
    std::unique_lock<std::mutex> finalizeLock(reportMutex);

    for (auto& it : reportList) {
        try {
            auto agentDataOffset = it->finalize(*getBuilder());
            auto agentDataVector = getBuilder()->CreateVector(&agentDataOffset, 1);

            auto bundle = fbs::CreateHexAgentDataBundle(*getBuilder(), agentDataVector);
            FinishHexAgentDataBundleBuffer(*getBuilder(), bundle);
            auto sharedThis = std::static_pointer_cast<HexContext>(shared_from_this());

            _publisher->publish(sharedThis);

            // Clear the builder for the next report
            getBuilder()->Clear();
        } catch (std::invalid_argument& e) {
            LLOG_AUDIT("Hex report not finalized: %s", e.what());
        } catch (...) {
            LLOG_AUDIT("Hex report not finalized:");
        }
    }
}

std::shared_ptr<Report::HexReport> HexReportContext::createReport(std::shared_ptr<Report::HandledException> exception) {
    return std::make_shared<Report::HexReport>(std::move(exception), _applicationInfo, _attributeValidator);
}

void HexReportContext::insert(std::shared_ptr<Report::HexReport> report) {
    std::unique_lock<std::mutex> insertLock(reportMutex);
    reportList.push_back(std::move(report));
}

unsigned long HexReportContext::reports() {
    std::unique_lock<std::mutex> countLock(reportMutex);
    return reportList.size();
}
