
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
    // Capture the store by value (shared_ptr) so the upload-completion callbacks,
    // which fire asynchronously after this method returns, keep it alive.
    std::shared_ptr<HexStore> store = _store;
    auto future = _store->readAll([this, store](uint8_t* buf, std::size_t size, const std::string& reportId) {
        auto verifier = flatbuffers::Verifier(buf, size);
        if (fbs::VerifyHexAgentDataBuffer(verifier)) {
            auto agentDataObj = UnPackHexAgentData(buf, nullptr);

            // Create a new context for each piece of agent data
            auto context = std::make_shared<HexContext>();
            flatbuffers::Offset<HexAgentData> agentDataOffset = HexAgentData::Pack(*context->getBuilder(), agentDataObj.get(), nullptr);

            Offset<Vector<Offset<HexAgentData>>> agentDataVector = context->getBuilder()->CreateVector(&agentDataOffset, 1);
            auto bundle = fbs::CreateHexAgentDataBundle(*context->getBuilder(), agentDataVector);
            FinishHexAgentDataBundleBuffer(*context->getBuilder(), bundle);

            // Publish the context for this agent data. The report is removed from disk
            // only when the publisher says so: shouldRemove==true on a confirmed upload
            // OR after the per-report retry limit is reached; false keeps it for retry.
            if (context) {
                _publisher->publish(context, reportId, [store, reportId](bool shouldRemove) {
                    if (shouldRemove) {
                        store->markUploaded(reportId);
                    } else {
                        store->markFailed(reportId);
                    }
                });
            } else {
                // Could not build a context to publish; release the in-flight mark
                // so the report is retried on the next pass.
                store->markFailed(reportId);
            }
        } else {
            // Un-verifiable flatbuffer: it can never be uploaded, so drop it
            // permanently rather than retrying it forever.
            store->markUploaded(reportId);
        }
    });

    future.get();
}

void NewRelic::Hex::HexPersistenceManager::publishContext(std::shared_ptr<HexContext>const& context) {
    _publisher->publish(context);
}
