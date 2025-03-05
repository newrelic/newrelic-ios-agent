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
                                   const AttributeValidator& attributeValidator)
        : HexContext::HexContext(),
          _attributeValidator(attributeValidator),
          _applicationInfo(applicationInfo) {}

void HexReportContext::finalize() {
    std::unique_lock<std::mutex> finalizeLock(reportMutex);
    std::vector<flatbuffers::Offset<fbs::HexAgentData>> agentDataList;
    for (auto& it : reportList) {
        try {
            agentDataList.push_back(it->finalize(*getBuilder()));
        } catch (std::invalid_argument& e) {
            LLOG_AUDIT("Hex report not finalized: %s", e.what());
        } catch (...) {
            LLOG_AUDIT("Hex report not finalized:");
        }
    }
    getBuilder()->CreateVector(agentDataList);

    auto bundle = fbs::CreateHexAgentDataBundle(*getBuilder(), getBuilder()->CreateVector(agentDataList));
    FinishHexAgentDataBundleBuffer(*getBuilder(), bundle);

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
