
//
// Created by Bryce Buchanan on 9/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "HexPersistenceManager.hpp"
#include "hex-agent-data-bundle_generated.h"
#include "jserror_generated.h"
#include <Utilities/libLogger.hpp>

using namespace NewRelic::Hex;
using namespace com::newrelic::mobile;

HexPersistenceManager::HexPersistenceManager(std::shared_ptr<HexStore>& store,
                                             HexPublisher* publisher) : _store(store),
                                                                        _publisher(publisher) {

}

void NewRelic::Hex::HexPersistenceManager::retrieveAndPublishReports() {
    auto future = _store->readAll([this](uint8_t* buf, std::size_t size) {
        auto verifier = flatbuffers::Verifier(buf, size);
        if (fbs::VerifyHexAgentDataBuffer(verifier)) {
            auto agentDataObj = UnPackHexAgentData(buf, nullptr);

            // Create a new context for each piece of agent data
            auto context = std::make_shared<HexContext>();
            flatbuffers::Offset<HexAgentData> agentDataOffset = HexAgentData::Pack(*context->getBuilder(), agentDataObj.get(), nullptr);

            Offset<Vector<Offset<HexAgentData>>> agentDataVector = context->getBuilder()->CreateVector(&agentDataOffset, 1);
            auto bundle = fbs::CreateHexAgentDataBundle(*context->getBuilder(), agentDataVector);
            FinishHexAgentDataBundleBuffer(*context->getBuilder(), bundle);

            // Publish the context for this agent data
            if (context) {
                _publisher->publish(context);
            }
        }
    });

    future.get();
}

void NewRelic::Hex::HexPersistenceManager::publishContext(std::shared_ptr<HexContext>const& context) {
    _publisher->publish(context);
}
