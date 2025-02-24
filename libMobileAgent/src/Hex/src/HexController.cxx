//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <utility>
#include "Hex/LibraryController.hpp"
#include "Hex/HexPublisher.hpp"
#include "Hex/HexController.hpp"

using namespace NewRelic::Hex;

HexController::HexController(std::shared_ptr<const AnalyticsController>& analytics,
                             std::shared_ptr<Report::AppInfo> applicationInfo,
                             HexPublisher* publisher,
                             std::shared_ptr<HexStore>& store,
                             const char* sessionId) :
        _analytics(std::shared_ptr<const AnalyticsController>{analytics}),
        _applicationInfo(std::move(applicationInfo)),
        _publisher(publisher),
        _store(store),
        _sessionId(sessionId),
        _keyContext(std::make_shared<HexReportContext>(_applicationInfo, _analytics->getAttributeValidator(), publisher)) {
}

HexController::HexController(std::shared_ptr<const AnalyticsController>&& analytics,
                             std::shared_ptr<Report::AppInfo> applicationInfo,
                             HexPublisher* publisher,
                             std::shared_ptr<HexStore>& store,
                             const char* sessionId) :
        _analytics(std::move(analytics)),
        _applicationInfo(std::move(applicationInfo)),
        _publisher(publisher),
        _store(store),
        _sessionId(sessionId),
        _keyContext(std::make_shared<HexReportContext>(_applicationInfo, _analytics->getAttributeValidator(), publisher)) {
}

// New Event System
std::shared_ptr<Report::HexReport> HexController::createReport(uint64_t epochMs,
                                                               const char* message,
                                                               const char* name,
                                                               const std::map <std::string, std::shared_ptr<AttributeBase>> attributes,
                                                               std::vector<std::shared_ptr<Report::Thread>> threads) {

    auto exception = std::make_shared<Report::HandledException>(_sessionId,
                                                                epochMs,
                                                                message,
                                                                name,
                                                                threads);
    auto report = _keyContext->createReport(exception);

    report->setAttributes(attributes);

    return report;
}

// Old Event System
std::shared_ptr<Report::HexReport> HexController::createReport(uint64_t epochMs,
                                                               const char* message,
                                                               const char* name,
                                                               std::vector<std::shared_ptr<Report::Thread>> threads) {

    auto exception = std::make_shared<Report::HandledException>(_sessionId,
                                                                epochMs,
                                                                message,
                                                                name,
                                                                threads);

    auto report = _keyContext->createReport(exception);

    report->setAttributes(_analytics->getSessionAttributes());

    return report;
}


std::shared_ptr<HexReportContext> HexController::detachKeyContext() {
    std::unique_lock<std::mutex> detachLock(_keyContextMutex);
    auto context = _keyContext;
    _keyContext = std::make_shared<HexReportContext>(_applicationInfo, _analytics->getAttributeValidator(), _publisher);
    return context;
}

void HexController::resetKeyContext() {
    std::unique_lock<std::mutex> resetLock(_keyContextMutex);
    _keyContext = std::make_shared<HexReportContext>(_applicationInfo, _analytics->getAttributeValidator(), _publisher);
}

void HexController::publish() {
    auto context = detachKeyContext();
    if (context->reports() > 0) {
        context->finalize();
       // _publisher->publish(context);
    }
}

void HexController::submit(std::shared_ptr<Report::HexReport> report) {
    std::unique_lock<std::mutex> submitLock(_keyContextMutex);
    _store->store(report);
    _keyContext->insert(std::move(report));
}

void HexController::setSessionId(const char* sessionId) {
    _sessionId = std::string(sessionId);
}



