//
// Created by Bryce Buchanan on 6/15/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Hex/HexPublisher.hpp"
#include <sstream>
#include <Utilities/libLogger.hpp>

using namespace NewRelic::Hex;

const char* HexPublisher::FILE_BASE = "NRExceptionReport";
const char* HexPublisher::FILE_EXTENSION = ".fbadb";

void NewRelic::Hex::HexPublisher::publish(std::shared_ptr<NewRelic::Hex::HexContext> const& context) {
    auto bufPointer = context->getBuilder()->GetBufferPointer();
    auto size = context->getBuilder()->GetSize();
    filename = writeBytesToStore(bufPointer, size);
}

std::string HexPublisher::lastPublishedFile() {
    return filename;
}

std::string HexPublisher::writeBytesToStore(uint8_t* bytes,
                                            size_t length) {
    auto filename = generateFilename();
    FILE* file = fopen(filename.c_str(), "wb");
    if (file == nullptr) {
        LLOG_VERBOSE("failed to write handled exception report.\nerror %d: %s", errno, strerror(errno));
        return std::string("");
    }

    auto size = fwrite(bytes, sizeof(uint8_t), length, file);

    if (size < length) {
        if (ferror(file)) {
            LLOG_VERBOSE("failed to write handled exception report.\nerror %d: %s", errno, strerror(errno));
            fclose(file);
            remove(filename.c_str());
        }
    }
    fclose(file);
    return filename;
}

std::string HexPublisher::generateFilename() {
    std::ostringstream ss;
    auto now = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
    ss << storePath << "/" << FILE_BASE << now << FILE_EXTENSION;
    return ss.str();
}

NewRelic::Hex::HexPublisher::HexPublisher(const char* storePath) : storePath(storePath) {}

