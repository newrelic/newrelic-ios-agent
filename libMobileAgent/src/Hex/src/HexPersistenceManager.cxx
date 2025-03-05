
//
// Created by Bryce Buchanan on 9/25/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "HexPersistenceManager.hpp"
#include "hex-agent-data-bundle_generated.h"
#include "jserror_generated.h"

using namespace NewRelic::Hex;
using namespace com::newrelic::mobile;

HexPersistenceManager::HexPersistenceManager(std::shared_ptr<HexStore>& store,
                                             HexPublisher* publisher) : _store(store),
                                                                        _publisher(publisher) {

}

std::shared_ptr<NewRelic::Hex::HexContext> NewRelic::Hex::HexPersistenceManager::retrieveStoreReports() {
    auto context = std::make_shared<HexContext>();
    std::vector<flatbuffers::Offset<fbs::HexAgentData>> agentDataVector;


    auto future = _store->readAll([&agentDataVector, &context](uint8_t* buf, std::size_t size) {
        auto verifier = flatbuffers::Verifier(buf, size);
        if(fbs::VerifyHexAgentDataBuffer(verifier)) {
            auto agentDataObj = UnPackHexAgentData(buf, nullptr);
            flatbuffers::Offset<HexAgentData> agentDataOffset = HexAgentData::Pack(*context->getBuilder(), agentDataObj.get(),
                                                                             nullptr);
            agentDataVector.push_back(agentDataOffset);
        }
    });

    future.get();

    if (agentDataVector.empty()) {
     return nullptr;
    }
    auto bundle = fbs::CreateHexAgentDataBundle(*context->getBuilder(),
                                             context->getBuilder()->CreateVector(agentDataVector));

    FinishHexAgentDataBundleBuffer(*context->getBuilder(), bundle);

    return context;
}

void NewRelic::Hex::HexPersistenceManager::publishContext(std::shared_ptr<HexContext>const& context) {
    _publisher->publish(context);
}
