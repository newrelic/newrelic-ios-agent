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
    for (Frame f : _frames) {
        frames.push_back(f.serialize(builder));
    }
    auto fbsFrames = builder.CreateVector(frames);
    return fbs::hex::CreateThread(builder, fbsFrames);
}
