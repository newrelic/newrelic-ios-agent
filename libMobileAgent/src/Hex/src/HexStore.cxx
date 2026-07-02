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
#include <mutex>
#include <unordered_set>
#include "Hex/HexStore.hpp"
#include <Utilities/libLogger.hpp>
#include <cstddef>
#include "hex-agent-data_generated.h"
#include "jserror_generated.h"

namespace {
    // Process-global set of report paths currently handed to a publisher whose upload
    // has not yet resolved. It is intentionally NOT per-HexStore: the agent can create
    // more than one NRMAHandledExceptions (hence more than one HexStore) over the SAME
    // on-disk directory during startup (e.g. initial start + the foreground-transition
    // session restart both run onSessionStart). A per-instance set would let each store
    // read and upload the same .fbad file. Keying a single process-wide set by absolute
    // file path guarantees each report is published at most once per process, regardless
    // of how many HexStore instances exist. Function-local statics avoid static-init-order
    // issues. The set is in-memory, so a fresh process starts empty and re-reads any file
    // still on disk (the desired crash/termination recovery).
    std::mutex& inFlightMutex() {
        static std::mutex m;
        return m;
    }
    std::unordered_set<std::string>& inFlightSet() {
        static std::unordered_set<std::string> s;
        return s;
    }

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

        std::future<bool> HexStore::readAll(std::function<void(uint8_t*,std::size_t,const std::string&)> callback) {

            std::string path = storePath;
            return std::async(std::launch::async, [callback, path, this]() {
                std::lock_guard<std::mutex> storeLock(_storeMutex);
                LLOG_VERBOSE("[HexDelete] readAll: begin pass over store dir \"%s\"", path.c_str());
                UniqueDir dirp(::opendir(path.c_str()));
                if (!dirp) {
                    LLOG_ERROR("[HexDelete] readAll: failed to open handled exception store dir: \"%s\".\nerror %d: %s",
                               path.c_str(), errno, std::strerror(errno));
                    return false;
                }
                std::size_t flushed = 0;
                struct dirent* dp = nullptr;
                while ((dp = ::readdir(dirp.get())) != nullptr) {
                    if (flushed >= kMaxReportsPerFlush) {
                        // Remaining files stay on disk; next harvest cycle picks them up.
                        // Prevents 100s of concurrent uploads when a backlog drains.
                        LLOG_VERBOSE("[HexDelete] readAll: per-pass flush cap (%zu) reached; "
                                     "remaining reports deferred to next pass", kMaxReportsPerFlush);
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

                    // Skip reports whose upload from a prior pass (or a concurrent
                    // HexStore instance over the same directory) has not yet resolved,
                    // so a pending report is not read and uploaded twice.
                    {
                        std::lock_guard<std::mutex> inFlightLock(inFlightMutex());
                        if (inFlightSet().count(fullPath)) {
                            LLOG_VERBOSE("[HexDelete] readAll: skipping report already in-flight: %s",
                                         fullPath.c_str());
                            continue;
                        }
                    }

                    std::ifstream file{fullPath.c_str(), std::ios::binary | std::ios::ate};
                    if (!file.good()) {
                        LLOG_ERROR("[HexDelete] readAll: report not readable, removing inline: %s",
                                   fullPath.c_str());
                        file.close();
                        std::remove(fullPath.c_str());
                        continue;
                    }
                    std::streamsize size = file.tellg();

                    if (size <= 0) {
                        // Corrupt / empty file — log, drop, and skip. Previously the code
                        // fell through to `new uint8_t[size]` with size == -1, allocating
                        // ~SIZE_MAX bytes (crash). Corrupt files can never upload, so they
                        // are still removed inline.
                        LLOG_ERROR("[HexDelete] readAll: dropping corrupt/empty handled exception report (size %lld): %s",
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
                        // Claim the report BEFORE handing off so an upload that resolves
                        // synchronously (or a concurrent pass / another HexStore instance)
                        // can't double-process it. Claim + skip-check share inFlightMutex,
                        // so the claim is atomic with respect to other readers.
                        {
                            std::lock_guard<std::mutex> inFlightLock(inFlightMutex());
                            if (!inFlightSet().insert(fullPath).second) {
                                // Another reader claimed it between the skip-check above
                                // and here; leave it to them.
                                LLOG_VERBOSE("[HexDelete] readAll: lost claim race for %s, "
                                             "leaving to other reader", fullPath.c_str());
                                file.close();
                                continue;
                            }
                            LLOG_VERBOSE("[HexDelete] readAll: claimed report in-flight (%zu bytes): %s "
                                         "(in-flight set size now %zu)",
                                         static_cast<std::size_t>(size), fullPath.c_str(),
                                         inFlightSet().size());
                        }
                        try {
                            LLOG_VERBOSE("[HexDelete] readAll: handing report to publisher: %s", fullPath.c_str());
                            callback(buf.get(), static_cast<std::size_t>(size), fullPath);
                            ++flushed;
                        } catch (...) {
                            // Never let a publisher exception leak the DIR* / buffer.
                            // The upload was never queued, so release the claim
                            // and leave the file for the next pass.
                            LLOG_ERROR("[HexDelete] readAll: publisher threw while consuming %s — "
                                       "releasing claim, keeping file for next pass", filename.c_str());
                            std::lock_guard<std::mutex> inFlightLock(inFlightMutex());
                            inFlightSet().erase(fullPath);
                        }
                    } else {
                        LLOG_ERROR("[HexDelete] readAll: failed to read file %s", filename.c_str());
                    }
                    file.close();
                    // NOTE: the report is intentionally NOT removed here. It is deleted
                    // only once its upload is confirmed via markUploaded().
                }
                LLOG_VERBOSE("[HexDelete] readAll: pass complete over \"%s\": handed %zu report(s) to publisher",
                             path.c_str(), flushed);
                return true;
            });
        }

        void HexStore::markUploaded(const std::string& reportId) {
            std::lock_guard<std::mutex> inFlightLock(inFlightMutex());
            int rc = std::remove(reportId.c_str());
            std::size_t erased = inFlightSet().erase(reportId);
            if (rc != 0) {
                LLOG_ERROR("[HexDelete] markUploaded: std::remove failed (rc=%d, errno=%d: %s) for %s "
                           "— file may already be gone or path mismatch", rc, errno,
                           std::strerror(errno), reportId.c_str());
            } else {
                LLOG_VERBOSE("[HexDelete] markUploaded: deleted confirmed report %s", reportId.c_str());
            }
            if (erased == 0) {
                LLOG_WARNING("[HexDelete] markUploaded: reportId was NOT in the in-flight set: %s "
                             "(double-resolve or unmatched key?)", reportId.c_str());
            }
        }

        void HexStore::markFailed(const std::string& reportId) {
            std::lock_guard<std::mutex> inFlightLock(inFlightMutex());
            // Leave the file on disk; just release the claim so the next readAll()
            // pass re-reads and re-uploads it.
            std::size_t erased = inFlightSet().erase(reportId);
            if (erased == 0) {
                LLOG_WARNING("[HexDelete] markFailed: reportId was NOT in the in-flight set: %s "
                             "(double-resolve or unmatched key?)", reportId.c_str());
            } else {
                LLOG_VERBOSE("[HexDelete] markFailed: kept report on disk for retry, released claim: %s",
                             reportId.c_str());
            }
        }

        void HexStore::clear() {
            {
                // Release only this store's in-flight claims (the global set may hold
                // claims for other directories).
                std::lock_guard<std::mutex> inFlightLock(inFlightMutex());
                auto& s = inFlightSet();
                // Match the store dir followed by a separator so sibling stores
                // sharing a prefix (e.g. "/hex" vs "/hex2") don't get erased.
                // Every claim is keyed as storePath + "/" + filename.
                std::string prefix = storePath + "/";
                std::size_t released = 0;
                for (auto it = s.begin(); it != s.end(); ) {
                    if (it->rfind(prefix, 0) == 0) {
                        it = s.erase(it);
                        ++released;
                    } else {
                        ++it;
                    }
                }
                LLOG_VERBOSE("[HexDelete] clear: released %zu in-flight claim(s) for prefix \"%s\" "
                             "and will delete all persisted reports", released, prefix.c_str());
            }
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
