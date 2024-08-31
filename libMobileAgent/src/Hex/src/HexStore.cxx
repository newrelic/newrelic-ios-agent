//
// Created by Bryce Buchanan on 9/21/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <sstream>
#include <fstream>
#include <future>
#include <dirent.h>
#include "Hex/HexStore.hpp"
#include <Utilities/libLogger.hpp>
#include <cstddef>
#include "hex-agent-data_generated.h"
#include "jserror_generated.h"

namespace NewRelic {
    namespace Hex {

        const char* HexStore::FILE_BASE = "NRExceptionReport";

        const char* HexStore::FILE_EXTENSION = ".fbad";


        HexStore::HexStore(const char* storePath) : storePath(storePath) {}

        void HexStore::store(const std::shared_ptr<Report::HexReport>& report) {
            auto filename = generateFilename();
            FILE* file = fopen(filename.c_str(), "wb");
            if (file == nullptr) {
                LLOG_ERROR("failed to write handled exception report to %s.\nerror %d: %s", filename.c_str(), errno,
                             strerror(errno));
                return;
            }
            flatbuffers::FlatBufferBuilder builder{};
            auto agentData = report->finalize(builder);
            builder.Finish(agentData);
            auto size = fwrite(builder.GetBufferPointer(), sizeof(uint8_t), builder.GetSize(), file);
            if (size < builder.GetSize()) {
                if (ferror(file)) {
                    LLOG_ERROR("failed to write handled exception report.\nerror %d: %s", errno, strerror(errno));
                }
            }
            fclose(file);
        }

        std::future<bool> HexStore::readAll(std::function<void(uint8_t*,std::size_t)> callback) {

            std::string path = storePath;
            return std::async(std::launch::async, [callback, path, this]() {
                std::lock_guard<std::mutex> storeLock(_storeMutex);
                DIR* dirp = opendir(path.c_str());
                if (dirp == nullptr) {
                    LLOG_ERROR("failed to open handled exception store dir: \"%s\".\nerror %d: %s", path.c_str(), errno,
                                 strerror(errno));
                    return false;
                }
                struct dirent* dp = nullptr;
                while ((dp = readdir(dirp)) != nullptr) {
                    std::string filename{dp->d_name};
                    if (filename.length() > 0) {
                        std::string extension{FILE_EXTENSION};
                        auto filenameLength = filename.length();
                        auto extensionLength = extension.length();
                        if (filenameLength > extensionLength &&
                            filename.substr(filenameLength - extensionLength, extensionLength) == extension) {
                            std::stringstream fullPath;
                            fullPath << path << "/" << filename;
                            std::ifstream file{fullPath.str().c_str(), std::ios::binary | std::ios::ate};
                            if (!file.good()) {
                                file.close();
                                remove(fullPath.str().c_str());
                                continue;
                            }
                            std::streamsize size = file.tellg();

                            if (size == -1) {
                                LLOG_ERROR("failed to get handled exception report file size: %s",filename.c_str());
                                file.close();
                            }

                            file.seekg(0, std::ios::beg);
                            auto buf = new uint8_t[size];
                            if (file.read((char*) buf, size)) {
                                callback(buf, size);
                            } else {
                                LLOG_ERROR("failed to read file %s",filename.c_str());
                            }
                            file.close();
                            remove(fullPath.str().c_str());
                            delete[] buf;
                        }
                    }
                }
                closedir(dirp);
                return true;
            });
        }

        void HexStore::clear() {
            std::string path = storePath;
            std::async(std::launch::async, [path, this]() {
                std::lock_guard<std::mutex> storeLock(_storeMutex);
                DIR* dirp = opendir(path.c_str());
                if (dirp == nullptr) {
                    LLOG_ERROR("failed to open handled exception store dir: \"%s\".\nerror %d: %s", path.c_str(), errno,
                               strerror(errno));
                    return;
                }

                struct dirent* dp = nullptr;
                while ((dp = readdir(dirp)) != nullptr) {
                    std::string filename{dp->d_name};
                    if (filename.length() > 0) {
                        std::string extension{FILE_EXTENSION};
                        auto filenameLength = filename.length();
                        auto extensionLength = extension.length();
                        if (filenameLength > extensionLength &&
                            filename.substr(filenameLength - extensionLength, extensionLength) == extension) {
                            std::stringstream fullPath;
                            fullPath << path << "/" << filename;
                            remove(fullPath.str().c_str());
                        }
                    }
                }
                closedir(dirp);
            });
        }

        std::string HexStore::generateFilename() {
            std::ostringstream ss;
            auto now = std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::system_clock::now().time_since_epoch()).count();
            ss << storePath << "/" << FILE_BASE << now << FILE_EXTENSION;
            return ss.str();
        }
    }
}
