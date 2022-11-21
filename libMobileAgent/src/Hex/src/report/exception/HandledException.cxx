//
// Created by Bryce Buchanan on 6/12/17.
//

#include <Hex/LibraryController.hpp>
#include "ios_generated.h"
#include "Thread.hpp"
#include "HandledException.hpp"


using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

// Build a container of Flatbuffer Libraries, given the global list of libraries found by LibraryController
std::vector<Offset<fbs::ios::Library>> buildLibraries(FlatBufferBuilder& builder) {
    std::vector<Offset<fbs::ios::Library>> libraries;

    auto& libraryController = NewRelic::LibraryController::getInstance();
    std::lock_guard<std::mutex> libraryLock(libraryController.getLibraryMutex());

    for (auto& l : libraryController.libraries()) {
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
        threads.push_back(t->serialize(builder));
    }

    auto fbsThreads = builder.CreateVector(threads);

    auto libraries = buildLibraries(builder);

    auto appImage = LibraryController::getInstance().getAppImage();

    auto fbsLibraries = builder.CreateVector(libraries);

    auto fbsHandledException = fbs::hex::HandledExceptionBuilder(builder);
    fbsHandledException.add_appUuidLow(appImage.uuidLow());
    fbsHandledException.add_appUuidHigh(appImage.uuidHigh());
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
