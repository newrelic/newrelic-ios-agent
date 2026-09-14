//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <Hex/LibraryController.hpp>
#include "ios_generated.h"
#include "Thread.hpp"
#include "HandledException.hpp"


using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

// Copy out the global library list found by LibraryController.
//
// This touches no flatbuffer state, so it IS safe to guard: if LibraryController
// is unavailable we serialize zero libraries rather than failing the whole
// report. Uses librariesSnapshot() so the lock is acquired internally and we
// copy out before serializing — avoids holding the mutex across flatbuffer
// writes and is safe even if the caller forgets to lock.
static std::vector<NewRelic::Hex::Report::Library> librarySnapshot() {
    try {
        return NewRelic::LibraryController::getInstance().librariesSnapshot();
    } catch (...) {
        return {};
    }
}

// Build a container of Flatbuffer Libraries from that snapshot.
//
// DO NOT wrap the serialization loop in try/catch. Library::serialize() writes
// into `builder` via CreateLibrary(), which opens a table. Swallowing an
// exception thrown part-way through leaves the builder with nested_ == true,
// and the next CreateString/CreateVector then trips
// FLATBUFFERS_ASSERT(!nested) — which aborts in debug and, because release
// builds define NDEBUG (ENABLE_NS_ASSERTIONS = NO), silently emits a malformed
// buffer in production. A half-written builder cannot be salvaged, so the throw
// must propagate and the caller must abandon the entire report. The crash
// boundary that catches it lives in -[NRMAHandledExceptions recordError:...]
// and its siblings. See GitHub issue #884 / NR-614312.
std::vector<Offset<fbs::ios::Library>> buildLibraries(FlatBufferBuilder& builder) {
    auto snapshot = librarySnapshot();

    std::vector<Offset<fbs::ios::Library>> libraries;
    libraries.reserve(snapshot.size());
    for (auto& l : snapshot) {
        libraries.push_back(l.serialize(builder));
    }
    return libraries;
}

Offset<Vector<Offset<fbs::hex::HandledException>>>
HandledException::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    auto fbsSessionId = builder.CreateString(_sessionId);
    auto fbsMessage = builder.CreateString(_message);
    auto fbsName = builder.CreateString(_name);

    std::vector<Offset<fbs::hex::Thread>> threads;
    for (auto const& t : _threads) {
        if (!t) continue;
        // Not guarded, for the same reason as buildLibraries(): Thread::serialize()
        // writes into `builder`, so swallowing a mid-write throw here would leave
        // the builder nested and corrupt the report. Let it propagate to the
        // crash boundary in NRMAHandledExceptions, which drops the report.
        threads.push_back(t->serialize(builder));
    }

    auto fbsThreads = builder.CreateVector(threads);

    auto libraries = buildLibraries(builder);

    // getAppImage() is guaranteed to return a valid (possibly zero-UUID)
    // Library even when no images have been registered — see
    // LibraryController::getAppImage(). This try/catch is safe to keep because
    // nothing in it writes to `builder`; it only copies a Library and reads two
    // integers off it, so swallowing here cannot leave the builder nested.
    uint64_t appUuidLow = 0;
    uint64_t appUuidHigh = 0;
    try {
        auto appImage = LibraryController::getInstance().getAppImage();
        appUuidLow = appImage.uuidLow();
        appUuidHigh = appImage.uuidHigh();
    } catch (...) {
        // Leave UUIDs at 0 on failure — backend treats this as "unknown".
    }

    auto fbsLibraries = builder.CreateVector(libraries);

    auto fbsHandledException = fbs::hex::HandledExceptionBuilder(builder);
    fbsHandledException.add_appUuidLow(appUuidLow);
    fbsHandledException.add_appUuidHigh(appUuidHigh);
    fbsHandledException.add_sessionId(fbsSessionId);
    fbsHandledException.add_timestampMs(_epochMs);
    fbsHandledException.add_name(fbsName);
    fbsHandledException.add_message(fbsMessage);
    fbsHandledException.add_cause(fbsMessage);
    fbsHandledException.add_threads(fbsThreads);
    fbsHandledException.add_libraries(fbsLibraries);

    auto exceptionVector = std::vector<Offset<fbs::hex::HandledException>>();

    exceptionVector.push_back(fbsHandledException.Finish());

    return builder.CreateVector(exceptionVector);
}


HandledException::HandledException(const std::string& sessionId,
                                   uint64_t epochMs,
                                   const char* message,
                                   const char* name,
                                   std::vector<std::shared_ptr<Thread>> threads) :
        _sessionId(sessionId),
        _epochMs(epochMs),
        _message(message),
        _name(name),
        _threads(std::move(threads)) {}

HandledException::~HandledException() {
    _threads.clear();
}
