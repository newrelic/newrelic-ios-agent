//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Thread.hpp"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

Thread::Thread(std::vector<Frame> frames) : _frames(std::move(frames)) {
}

Offset<fbs::hex::Thread> Thread::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    std::vector<Offset<fbs::hex::Frame>> frames;
    frames.reserve(_frames.size());
    // Iterate by const reference. The loop previously copied each Frame by
    // value — four std::string members apiece — and a handled-exception
    // report captures up to 1024 frames, so this was ~4096 needless heap
    // allocations per recordError: call, all on the caller's thread.
    for (const auto& f : _frames) {
        frames.push_back(f.serialize(builder));
    }
    auto fbsFrames = builder.CreateVector(frames);
    return fbs::hex::CreateThread(builder, fbsFrames);
}
