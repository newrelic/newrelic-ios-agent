//
// Created by Bryce Buchanan on 9/21/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <sstream>
#include <fstream>
#include <future>
#include <thread>
#include <dirent.h>
#include <sys/stat.h>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <memory>
#include <vector>
#include "Hex/HexStore.hpp"
#include <Utilities/libLogger.hpp>
#include <cstddef>
#include "hex-agent-data_generated.h"
#include "jserror_generated.h"

namespace {
    // Max number of persisted .fbad reports we keep on disk. Beyond this we evict
    // the oldest by mtime. Bounds disk + FD pressure when uploads cannot drain.
    constexpr std::size_t kMaxBacklog = 100;

    // Max reports we callback() out per readAll() pass — prevents a 200-deep
    // backlog from spawning 200 concurrent uploads on cold start.
    constexpr std::size_t kMaxReportsPerFlush = 25;

    struct FileCloser {
        void operator()(FILE* f) const noexcept { if (f) std::fclose(f); }
    };
    struct DirCloser {
        void operator()(DIR* d) const noexcept { if (d) ::closedir(d); }
    };
    using UniqueFile = std::unique_ptr<FILE, FileCloser>;
    using UniqueDir  = std::unique_ptr<DIR,  DirCloser>;

    // Returns count of matching files remaining on disk after eviction.
    // Walks `path` once, sorts by mtime, removes oldest until count <= cap.
    std::size_t evictOldestIfOver(const std::string& path,
                                  const std::string& extension,
                                  std::size_t cap) {
        UniqueDir dirp(::opendir(path.c_str()));
        if (!dirp) return 0;

        std::vector<std::pair<time_t, std::string>> entries;
        entries.reserve(cap + 16);

        struct dirent* dp = nullptr;
        while ((dp = ::readdir(dirp.get())) != nullptr) {
            std::string filename{dp->d_name};
            if (filename.length() <= extension.length()) continue;
            if (filename.compare(filename.length() - extension.length(),
                                 extension.length(), extension) != 0) {
                continue;
            }
            std::string full = path + "/" + filename;
            struct stat st{};
            if (::stat(full.c_str(), &st) == 0) {
                entries.emplace_back(st.st_mtime, std::move(full));
            }
        }

        if (entries.size() <= cap) {
            return entries.size();
        }

        std::sort(entries.begin(), entries.end(),
                  [](const auto& a, const auto& b) { return a.first < b.first; });

        std::size_t toRemove = entries.size() - cap;
        for (std::size_t i = 0; i < toRemove; ++i) {
            std::remove(entries[i].second.c_str());
        }
        return cap;
    }
}

namespace NewRelic {
    namespace Hex {

        const char* HexStore::FILE_BASE = "NRExceptionReport";

        const char* HexStore::FILE_EXTENSION = ".fbad";


        HexStore::HexStore(const char* storePath) : storePath(storePath) {}

        void HexStore::store(const std::shared_ptr<Report::HexReport>& report) {
            // Bound the on-disk backlog before we add another file. Cheap single
            // dirent walk; protects against an indefinitely-offline app from
            // exhausting disk + file descriptors.
            evictOldestIfOver(storePath, FILE_EXTENSION, kMaxBacklog);

            auto filename = generateFilename();
            UniqueFile file(std::fopen(filename.c_str(), "wb"));
            if (!file) {
                int saved = errno;
                LLOG_ERROR("failed to write handled exception report to %s.\nerror %d: %s",
                           filename.c_str(), saved, std::strerror(saved));
                if (saved == EMFILE || saved == ENFILE) {
                    // FD table is full — aggressively drop oldest backlog so we
                    // don't sit in a tight retry loop hitting the same wall.
                    evictOldestIfOver(storePath, FILE_EXTENSION, kMaxBacklog / 2);
                }
                return;
            }
            flatbuffers::FlatBufferBuilder builder{};
            auto agentData = report->finalize(builder);
            builder.Finish(agentData);
            auto size = std::fwrite(builder.GetBufferPointer(), sizeof(uint8_t),
                                    builder.GetSize(), file.get());
            if (size < builder.GetSize()) {
                if (std::ferror(file.get())) {
                    LLOG_ERROR("failed to write handled exception report.\nerror %d: %s",
                               errno, std::strerror(errno));
                }
            }
            // file closed by UniqueFile dtor on every exit path.
        }

        std::future<bool> HexStore::readAll(std::function<void(uint8_t*,std::size_t)> callback) {

            std::string path = storePath;
            return std::async(std::launch::async, [callback, path, this]() {
                std::lock_guard<std::mutex> storeLock(_storeMutex);
                UniqueDir dirp(::opendir(path.c_str()));
                if (!dirp) {
                    LLOG_ERROR("failed to open handled exception store dir: \"%s\".\nerror %d: %s",
                               path.c_str(), errno, std::strerror(errno));
                    return false;
                }
                std::size_t flushed = 0;
                struct dirent* dp = nullptr;
                while ((dp = ::readdir(dirp.get())) != nullptr) {
                    if (flushed >= kMaxReportsPerFlush) {
                        // Remaining files stay on disk; next harvest cycle picks them up.
                        // Prevents 100s of concurrent uploads when a backlog drains.
                        break;
                    }
                    std::string filename{dp->d_name};
                    if (filename.length() == 0) continue;

                    std::string extension{FILE_EXTENSION};
                    auto filenameLength = filename.length();
                    auto extensionLength = extension.length();
                    if (filenameLength <= extensionLength ||
                        filename.substr(filenameLength - extensionLength, extensionLength) != extension) {
                        continue;
                    }

                    std::string fullPath = path + "/" + filename;
                    std::ifstream file{fullPath.c_str(), std::ios::binary | std::ios::ate};
                    if (!file.good()) {
                        file.close();
                        std::remove(fullPath.c_str());
                        continue;
                    }
                    std::streamsize size = file.tellg();

                    if (size <= 0) {
                        // Corrupt / empty file — log, drop, and skip. Previously the code
                        // fell through to `new uint8_t[size]` with size == -1, allocating
                        // ~SIZE_MAX bytes (crash).
                        LLOG_ERROR("dropping handled exception report (size %lld): %s",
                                   static_cast<long long>(size), filename.c_str());
                        file.close();
                        std::remove(fullPath.c_str());
                        continue;
                    }

                    file.seekg(0, std::ios::beg);
                    std::unique_ptr<uint8_t[]> buf(new (std::nothrow) uint8_t[size]);
                    if (!buf) {
                        LLOG_ERROR("failed to allocate %lld bytes reading %s",
                                   static_cast<long long>(size), filename.c_str());
                        file.close();
                        continue;
                    }
                    if (file.read(reinterpret_cast<char*>(buf.get()), size)) {
                        try {
                            callback(buf.get(), static_cast<std::size_t>(size));
                            ++flushed;
                        } catch (...) {
                            // Never let a publisher exception leak the DIR* / buffer.
                            LLOG_ERROR("publisher threw while consuming %s — continuing",
                                       filename.c_str());
                        }
                    } else {
                        LLOG_ERROR("failed to read file %s", filename.c_str());
                    }
                    file.close();
                    std::remove(fullPath.c_str());
                }
                return true;
            });
        }

        void HexStore::clear() {
            std::string path = storePath;
            // Honor the original async intent without the std::async-discarded-future
            // gotcha (~future() of a launch::async future blocks). Use a detached
            // thread so callers don't stall on disk I/O.
            std::thread([path]() {
                UniqueDir dirp(::opendir(path.c_str()));
                if (!dirp) {
                    LLOG_ERROR("failed to open handled exception store dir: \"%s\".\nerror %d: %s",
                               path.c_str(), errno, std::strerror(errno));
                    return;
                }

                std::string extension{FILE_EXTENSION};
                auto extensionLength = extension.length();

                struct dirent* dp = nullptr;
                while ((dp = ::readdir(dirp.get())) != nullptr) {
                    std::string filename{dp->d_name};
                    if (filename.length() <= extensionLength) continue;
                    if (filename.substr(filename.length() - extensionLength, extensionLength) != extension) {
                        continue;
                    }
                    std::string fullPath = path + "/" + filename;
                    std::remove(fullPath.c_str());
                }
            }).detach();
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
