//  Copyright © 2023 New Relic. All rights reserved.

#include <unistd.h>
#include <Analytics/CacheBackedStore.hpp>
#include <Utilities/libLogger.hpp>
#include <Utilities/WorkQueue.hpp>
#include <Analytics/AnalyticEvent.hpp>
#include <atomic>
#include <chrono>
#include <future>
#include <memory>
#include <sstream>


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

    std::chrono::time_point<std::chrono::system_clock> lastWriteTime;
    std::atomic<bool> dirtyFlag{false};
    WorkQueue workQueue;
    std::shared_future<void> _initialLoadFuture;

    void waitForInitialLoad() const {
        if (_initialLoadFuture.valid()) {
            _initialLoadFuture.wait();
        }
    }

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
        clearBackup();
        // Run the initial file load on the work queue so the constructor doesn't block
        // the calling thread. Reads via get()/getCache()/load() wait on _initialLoadFuture;
        // writes via store()/remove() naturally serialize behind this work item.
        auto loadPromise = std::make_shared<std::promise<void>>();
        _initialLoadFuture = loadPromise->get_future().share();
        workQueue.enqueue([this, loadPromise] {
            try {
                loadFromFile();
            } catch (...) {
                LLOG_VERBOSE("Initial async load failed: %s", _fullPath.c_str());
            }
            loadPromise->set_value();
        });
    };

    void synchronize() {
        workQueue.synchronize();
    }

    bool synchronize(unsigned int timeout_ms) {
        return workQueue.synchronize(timeout_ms);
    }


    virtual ~FileBackedStore() {
        bool completed = workQueue.terminate(500);
        if (!completed) {
            LLOG_VERBOSE("WorkQueue terminate timed out in FileBackedStore destructor - thread detached");
        }

        std::lock_guard<std::mutex> lk(_fileMutex);
        if (dirtyFlag.load()) {
            flush();
        }
        if (_fO.is_open())
            _fO.close();
    }

    virtual void clear() {
        CacheBackedStore<K, T>::clear();
        workQueue.enqueue([this] {
            try {
                std::lock_guard<std::mutex> lk(_fileMutex);
                _fO.close();
                _fO.open(_fullPath, std::ios::trunc);
                _fO.rdbuf()->pubsetbuf(0, 0);
            } catch (std::exception& e) {
                LLOG_VERBOSE("failed to clear file: %s\nreason: %s", _fullPath.c_str(), e.what());
            } catch (...) {
                LLOG_VERBOSE("Failed to clear file: %s", _fullPath.c_str());
            }
        });
    }

    virtual void store(K key,
                       std::shared_ptr<T> obj) {
        {
            // Set dirtyFlag inside the cache lock so an async loadFromFile()
            // running on the work queue can't read it as "clean" between our
            // map mutation and our flag set.
            std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
            CacheBackedStore<K, T>::map[key] = obj;
            dirtyFlag = true;
        }
        workQueue.enqueue([this] {
            try {
                std::lock_guard<std::mutex> lk(_fileMutex);
                // Check throttle, but don't block the worker thread with sleep
                // This allows synchronize() and terminate() to complete faster
                auto now = std::chrono::system_clock::now();
                if (now - lastWriteTime >= writeThrottle()) {
                    flush();
                }
                // If throttled, the dirty flag remains set and will be flushed
                // on next store() call or in destructor
            } catch (std::exception& e) {
                LLOG_VERBOSE("Failed to store item: %s", e.what());
            } catch (...) {
                LLOG_VERBOSE("Failed to store item.");
            }
        });
    }

    virtual void remove(K key) {
        {
            std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
            CacheBackedStore<K, T>::map.erase(key);
            dirtyFlag = true;
        }
        workQueue.enqueue([this] {
            try {
                std::lock_guard<std::mutex> lk(_fileMutex);
                flush();
            } catch (std::exception& e) {
                LLOG_VERBOSE("Failed to remove item: %s", e.what());
            } catch (...) {
                LLOG_VERBOSE("Failed to remove item.");
            }
        });
    }

    virtual std::map<K, std::shared_ptr<T>> load() {
        waitForInitialLoad();
        std::lock_guard<std::mutex> lk(_fileMutex);
        CacheBackedStore<K, T>::clear();
        loadFromFile();
        std::lock_guard<std::mutex> mlk(CacheBackedStore<K, T>::m);
        return CacheBackedStore<K, T>::map;
    }

    virtual void flush() {
        writeToFile();
    }

    virtual std::shared_ptr<T> get(K key) {
        waitForInitialLoad();
        std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
        auto it = CacheBackedStore<K, T>::map.find(key);
        return it == CacheBackedStore<K, T>::map.end() ? nullptr : it->second;
    }

    virtual const char* getFullStorePath() const {
        return _fullPath.c_str();
    }

    const std::map<K, std::shared_ptr<T>> swap() {
        // Must wait for the initial async load BEFORE taking any locks. The
        // worker thread needs m to finish the load, so holding m here while
        // waiting on _initialLoadFuture would deadlock.
        waitForInitialLoad();

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

        // Read the map directly under the lock we already hold. Do NOT call
        // getCache() here — it would re-take m on a non-recursive mutex.
        auto map = CacheBackedStore<K, T>::map;
        CacheBackedStore<K, T>::map.clear();

        return map;
    }

    virtual std::map<K, std::shared_ptr<T>> getCache() {
        waitForInitialLoad();
        std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
        return CacheBackedStore<K, T>::map;
    }

protected:
    static std::shared_ptr<T> read(std::istream& is) {
        std::shared_ptr<T> t = std::make_shared<T>();
        is >> (*t);
        return t;
    }

    void loadFromFile() {
        // Read the entire file into a local map BEFORE taking the cache mutex.
        // Holding CacheBackedStore::m during file I/O is what froze callers:
        // every store()/remove() also takes m, so a slow file read on the
        // work queue blocked the calling thread for the duration.
        std::ifstream _fI;
        _fI.open(_fullPath);

        if (!_fI.is_open()) {
            std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
            if (!dirtyFlag.load()) {
                // No file and no pending writes: cache matches "disk" (empty).
                dirtyFlag = false;
            }
            return;
        }

        _fI.seekg(0, std::ios::end);
        std::streampos fileSize = _fI.tellg();
        _fI.seekg(0, std::ios::beg);

        const std::streampos MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
        if (fileSize > MAX_FILE_SIZE) {
            LLOG_VERBOSE("FileBackedStore file too large (%lld bytes), skipping load: %s",
                        static_cast<long long>(fileSize), _fullPath.c_str());
            _fI.close();
            return;
        }

        std::map<K, std::shared_ptr<T>> tmp;
        try {
            const int MAX_ENTRIES = 10000;
            int entryCount = 0;
            std::string key;
            std::string value;

            while (std::getline(_fI, key) && entryCount < MAX_ENTRIES) {
                if (!std::getline(_fI, value)) {
                    LLOG_VERBOSE("Malformed file, missing value for key: %s", _fullPath.c_str());
                    break;
                }

                K k{key};
                std::stringstream is{value};

                std::shared_ptr<T> t = _factory(is);
                if (_validator(k, t)) {
                    tmp[k] = t;
                }

                entryCount++;
            }

            if (entryCount >= MAX_ENTRIES) {
                LLOG_VERBOSE("FileBackedStore exceeded max entries (%d), truncating: %s",
                            MAX_ENTRIES, _fullPath.c_str());
            }
        } catch (...) {
            LLOG_VERBOSE("Exception during file load, dropping partial result: %s", _fullPath.c_str());
            _fI.close();
            return;
        }
        _fI.close();

        // Brief lock to merge into the cache. emplace() preserves any keys
        // that were store()d concurrently while we were reading the file —
        // those represent newer values than what's on disk.
        std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
        bool wasClean = !dirtyFlag.load();
        for (auto& kv : tmp) {
            CacheBackedStore<K, T>::map.emplace(kv.first, kv.second);
        }
        if (wasClean) {
            // No concurrent writes happened during the read, so cache now
            // matches disk. If wasClean was false, leave dirtyFlag set so
            // the queued flush will write the concurrent store(s) out.
            dirtyFlag = false;
        }
    }

    void writeToFile() {
        std::lock_guard<std::mutex> lk(CacheBackedStore<K, T>::m);
        auto map = CacheBackedStore<K, T>::map;

        if (dirtyFlag) {
            if (!_fO.is_open()) {
                _fO.open(_fullPath);
                _fO.rdbuf()->pubsetbuf(0, 0);
            }

            _fO.seekp(0);
            for (auto it = map.cbegin(); it != map.cend(); it++) {
                _fO << it->first << std::endl << std::flush;
                _fO << *(it->second) << std::endl << std::flush;
            }
            _fO.flush();

            // Update the file meta with real size, to exclude lingering data
            auto rc = truncate(getFullStorePath(), _fO.tellp());
            if (-1 == rc) {
                LLOG_VERBOSE("File truncation failed on \"%s\". Errno: %d", getFullStorePath(), errno);
            }

            dirtyFlag = false;
            lastWriteTime = std::chrono::system_clock::now();
        }

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

