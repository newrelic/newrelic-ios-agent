//  Copyright © 2023 New Relic. All rights reserved.

#include <unistd.h>
#include <Analytics/CacheBackedStore.hpp>
#include <Utilities/libLogger.hpp>
#include <Utilities/WorkQueue.hpp>
#include <Analytics/AnalyticEvent.hpp>
#include <atomic>
#include <chrono>
#include <sstream>
#include <thread>


#ifndef LIBMOBILEAGENT_FILEBACKEDSTORE_HPP
#define LIBMOBILEAGENT_FILEBACKEDSTORE_HPP
namespace NewRelic {
template<typename K, typename T>
class FileBackedStore : public CacheBackedStore<K, T> {

private:
    const char* BACKUP_SUFFIX = ".bak";
    mutable std::mutex _fileMutex;
    std::ofstream _fO;
    std::string _fullPath;

    std::shared_ptr<T> (* _factory)(std::istream&) = &FileBackedStore::read;

    bool (* _validator)(K const& k,
                        std::shared_ptr<T> t);

    std::chrono::steady_clock::time_point lastWriteTime;
    std::atomic<bool> dirtyFlag{false};
    // Set while a write is queued but hasn't snapshotted the cache yet; anything
    // stored or removed in the meantime rides along on that write.
    std::atomic<bool> writeScheduled{false};
    WorkQueue workQueue;

public:
    static const inline std::chrono::time_point<std::chrono::system_clock>::duration writeThrottle() {
        return std::chrono::milliseconds(25);
    }

    FileBackedStore() : FileBackedStore("temp") {}

    FileBackedStore(const char* filename) : FileBackedStore(filename, "") {}

    FileBackedStore(const char* filename,
                    const char* sharedPath)
            : FileBackedStore(filename, sharedPath, &FileBackedStore::read) {}

    FileBackedStore(const char* filename,
                    const char* sharedPath,
                    std::shared_ptr<T>(* factory)(std::istream&))
            : FileBackedStore(filename, sharedPath, factory, [](K const& k,
                                                                std::shared_ptr<T> t) { return true; }) {}

    FileBackedStore(const char* filename,
                    const char* sharedPath,
                    std::shared_ptr<T>(* factory)(std::istream&),
                    bool(* validator)(K const&,
                                      std::shared_ptr<T>))
            : CacheBackedStore<K, T>(),
              _fO{},
              _fullPath(getFullPath(sharedPath, filename)),
              _factory(factory),
              _validator(validator),
              lastWriteTime(),
              workQueue() {
        loadFromFile();
        clearBackup();
    };

    void synchronize() {
        workQueue.synchronize();
    }

    bool synchronize(unsigned int timeout_ms) {
        return workQueue.synchronize(timeout_ms);
    }


    virtual ~FileBackedStore() {
        // Use non-blocking terminate with 500ms timeout to avoid blocking main thread
        // If timeout occurs, thread will be detached and finish asynchronously
        bool completed = workQueue.terminate(500);
        if (!completed) {
            LLOG_VERBOSE("WorkQueue terminate timed out in FileBackedStore destructor - thread detached");
        }

        std::lock_guard<std::mutex> lk(_fileMutex);
        if (dirtyFlag) {
            writeToFile();
        }
        if (_fO.is_open())
            _fO.close();
    }

    virtual void clear() {
        CacheBackedStore<K, T>::clear();
        scheduleWrite();
    }

    virtual void store(K key,
                       std::shared_ptr<T> obj) {
        CacheBackedStore<K, T>::store(key, obj);
        scheduleWrite();
    }

    virtual void remove(K key) {
        CacheBackedStore<K, T>::remove(key);
        scheduleWrite();
    }

    virtual std::map<K, std::shared_ptr<T>> load() {
        std::lock_guard<std::mutex> lk(_fileMutex);
        CacheBackedStore<K, T>::clear();
        loadFromFile();
        return CacheBackedStore<K, T>::map;
    }

    virtual void flush() {
        std::lock_guard<std::mutex> lk(_fileMutex);
        writeToFile();
    }

    virtual std::shared_ptr<T> get(K key) {
        auto map = CacheBackedStore<K, T>::map;
        return map[key];
    }

    virtual const char* getFullStorePath() const {
        return _fullPath.c_str();
    }

    const std::map<K, std::shared_ptr<T>> swap() {
        std::lock_guard<std::mutex> flk(_fileMutex);
        std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
        if (_fO.is_open()) {
            _fO.flush();
            _fO.close();
        }

        std::string backupStorePath = std::string(getFullStorePath()) + BACKUP_SUFFIX;
        auto result = rename(getFullStorePath(), backupStorePath.c_str());
        if (result == 0) {
            _fO.open(_fullPath, std::ios::trunc);
            _fO.rdbuf()->pubsetbuf(0, 0);
        } else {
            LLOG_VERBOSE("failed to create backup store: %s", backupStorePath.c_str());
        }

        // save cache data as return result, but clear the internal cache
        auto map = getCache();
        CacheBackedStore<K, T>::map.clear();

        return map;
    }

    virtual std::map<K, std::shared_ptr<T>> getCache() {
        return CacheBackedStore<K, T>::map;
    }

protected:
    static std::shared_ptr<T> read(std::istream& is) {
        std::shared_ptr<T> t = std::make_shared<T>();
        is >> (*t);
        return t;
    }

    void loadFromFile() {
        std::ifstream _fI;
        std::string key;
        std::string value;

        std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
        _fI.open(_fullPath);
        const std::streamoff offset = std::streamoff(0);
        _fI.seekg(offset, std::ios_base::beg);

        try {
            while (std::getline(_fI, key)) {
                std::getline(_fI, value);
                K k{key};
                std::stringstream is{value};

                std::shared_ptr<T> t = _factory(is);
                if (_validator(k, t)) {
                    CacheBackedStore<K, T>::map[k] = t;
                }
            }
        } catch (...) {
            const std::streamoff offset = std::streamoff(0);
            _fI.seekg(offset, std::ios_base::beg);
            CacheBackedStore<K, T>::map.clear();
        }
        _fI.close();
        dirtyFlag = false;
    }

    // Marks the cache dirty and makes sure a write is queued. The write snapshots the
    // cache when it runs, so one queued write covers every change made before it
    // starts instead of queueing a full rewrite per call.
    void scheduleWrite() {
        dirtyFlag = true;
        if (writeScheduled.exchange(true)) {
            return;
        }
        workQueue.enqueue([this] {
            try {
                std::unique_lock<std::mutex> lk(_fileMutex);
                auto sinceLastWrite = std::chrono::steady_clock::now() - lastWriteTime;
                if (sinceLastWrite < writeThrottle()) {
                    lk.unlock();
                    std::this_thread::sleep_for(writeThrottle() - sinceLastWrite);
                    lk.lock();
                }
                // Cleared before the snapshot: a change that still sees it set is in the
                // snapshot, and a change that sees it cleared queues the next write.
                writeScheduled = false;
                writeToFile();
            } catch (std::exception& e) {
                writeScheduled = false;
                LLOG_VERBOSE("Failed to write store: %s", e.what());
            } catch (...) {
                writeScheduled = false;
                LLOG_VERBOSE("Failed to write store.");
            }
        });
    }

    // Caller must hold _fileMutex.
    void writeToFile() {
        std::map<K, std::shared_ptr<T>> snapshot;
        {
            // Only hold the cache lock long enough to copy the cache. store() and remove()
            // are called with EventManager's events lock held, and the main thread waits on
            // that lock, so file I/O must never happen under it.
            std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
            if (!dirtyFlag) {
                return;
            }
            snapshot = CacheBackedStore<K, T>::map;
            dirtyFlag = false;
        }

        // Reopen a stream an earlier write left failed (e.g. disk full), otherwise every
        // later write would silently do nothing.
        if (!_fO.is_open() || !_fO.good()) {
            _fO.close();
            _fO.clear();
            _fO.open(_fullPath);
            _fO.rdbuf()->pubsetbuf(0, 0);
        }

        _fO.seekp(0);
        // _fO is unbuffered, so serialize into memory and hand it large chunks rather
        // than paying a write(2) per token.
        const std::streamoff chunkSize = 64 * 1024;
        std::ostringstream chunk;
        for (auto it = snapshot.cbegin(); it != snapshot.cend(); it++) {
            chunk << it->first << '\n';
            chunk << *(it->second) << '\n';
            if (chunk.tellp() >= chunkSize) {
                writeChunk(chunk);
            }
        }
        writeChunk(chunk);
        _fO.flush();

        // Update the file meta with real size, to exclude lingering data
        auto rc = truncate(getFullStorePath(), _fO.tellp());
        if (-1 == rc) {
            LLOG_VERBOSE("File truncation failed on \"%s\". Errno: %d", getFullStorePath(), errno);
        }

        lastWriteTime = std::chrono::steady_clock::now();
    }

    void writeChunk(std::ostringstream& chunk) {
        const std::string bytes = chunk.str();
        _fO.write(bytes.data(), bytes.size());
        chunk.str("");
    }

protected:

    virtual std::string getFullPath(std::string filePath,
                                    std::string fileName) {
        if (filePath.length() > 0) {
            return filePath + "/" + fileName;
        } else {
            return fileName;
        }
    }

    void clearBackup() {
        std::string backupStorePath = std::string(getFullStorePath()) + BACKUP_SUFFIX;
        std::remove(backupStorePath.c_str());
    }
};
} // namespace NewRelic

#endif // LIBMOBILEAGENT_FILEBACKEDSTORE_HPP

