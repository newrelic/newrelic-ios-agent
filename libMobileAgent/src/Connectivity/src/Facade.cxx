//  Copyright © 2023 New Relic. All rights reserved.


#include <memory>
#include <chrono>

#include <mutex>
#include <Utilities/Application.hpp>
#include <Connectivity/GuidGenerator.hpp>
#include <Connectivity/Facade.hpp>


namespace NewRelic {
namespace Connectivity {

IFacade* Facade::__instance = nullptr;

IFacade& Facade::getInstance() {
    if (Facade::__instance == nullptr) {
        Facade::__instance = new Facade();
    }
    return *Facade::__instance;
}

std::unique_ptr<Payload> Facade::newPayload() {
    std::lock_guard<std::recursive_mutex> lock(_writeMutex);

    if(!Application::getInstance().isValid()) {
        return nullptr;
    }

    auto payload = std::make_unique<Payload>();
    payload->setAccountId(Application::getInstance().getContext().getAccountId());
    payload->setAppId(Application::getInstance().getContext().getApplicationId());
    payload->setId(GuidGenerator::newGUID());
    payload->setTraceId(_currentTraceId);
    payload->setParentId(_currentParentId);
    payload->setTimestamp(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count());

    return payload;
}

std::unique_ptr<Payload> Facade::startTrip() {

    if(!Application::getInstance().isValid()) {
        return nullptr;
    }

    std::lock_guard<std::recursive_mutex> lock(_writeMutex);
    _currentTraceId = GuidGenerator::newGUID32();
    _currentParentId = "";
    auto payload = newPayload();
    _currentParentId = payload->getId();
    return payload;
}

} // namespace Connectivity
} // namespace NewRelic
