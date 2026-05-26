//
// Created by Jared Stanbrough on 6/26/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_LIBRARYCONTROLLER_HPP
#define LIBMOBILEAGENT_LIBRARYCONTROLLER_HPP

#include <vector>
#include <mutex>
#include <atomic>
#include <Hex/Library.hpp>
#include <Hex/ios_generated.h>

using namespace com::newrelic::mobile;
using std::vector;

namespace NewRelic {
    class LibraryController {
    public:
        static LibraryController& getInstance() {
            static LibraryController instance;
            instance.ensureInitialized();
            return instance;
        }

        void add_library(const char* name,
                         const uint8_t* uuid,
                         uint64_t address,
                         com::newrelic::mobile::fbs::ios::Arch arch,
                         uint64_t size
        );

        std::vector<Hex::Report::Library> libraries() {
            return library_images;
        }

        // Returns a snapshot of the library list under the internal lock.
        // Prefer this over libraries() when the caller cannot guarantee it
        // is already holding getLibraryMutex().
        std::vector<Hex::Report::Library> librariesSnapshot() {
            std::lock_guard<std::mutex> libraryLock(libraryContainerMutex);
            return library_images;
        }

        size_t num_images() {
            std::lock_guard<std::mutex> libraryLock(libraryContainerMutex);

            return library_images.size();
        }

        // Returns the app image (the first registered library).
        // If no images have been registered yet (e.g. dyld add-image
        // callbacks have not fired, or registration failed), returns a
        // zero-initialized placeholder Library instead of indexing into
        // an empty vector. Callers should treat a zero UUID as "unknown".
        const Hex::Report::Library getAppImage() {
            std::lock_guard<std::mutex> libraryLock(libraryContainerMutex);

            if (library_images.empty()) {
                return Hex::Report::Library(std::string(),
                                            0,
                                            0,
                                            0,
                                            false,
                                            com::newrelic::mobile::fbs::ios::Arch::Arch_arm64,
                                            0);
            }
            return library_images.front();
        }

        bool hasAppImage() {
            std::lock_guard<std::mutex> libraryLock(libraryContainerMutex);
            return !library_images.empty();
        }

        std::mutex& getLibraryMutex() {
            return libraryContainerMutex;
        }

        LibraryController(LibraryController const& copy) = delete;

        void operator=(LibraryController const&) = delete;

    private:
        std::vector<std::string> USER_LIBRARY_PATHS;
        std::vector<Hex::Report::Library> library_images;
        mutable std::mutex libraryContainerMutex;

        LibraryController() : library_images() {
            USER_LIBRARY_PATHS = {"/private", "/var/containers/Bundle/Application",
                                  "/var/mobile/Containers/Bundle/Application", "/var/mobile/Applications/"};
        };

        void register_handler();

        std::atomic<bool> initialized{false};
        std::mutex initMutex;

        void ensureInitialized() {
            // Fast path: already initialized.
            if (initialized.load(std::memory_order_acquire)) return;

            std::lock_guard<std::mutex> lock(initMutex);
            if (initialized.load(std::memory_order_relaxed)) return;

            // CRITICAL: set the flag BEFORE calling register_handler().
            // _dyld_register_func_for_add_image synchronously invokes our
            // handler for every already-loaded image on this thread, and
            // that handler calls LibraryController::getInstance() which
            // re-enters ensureInitialized(). With the flag set first, the
            // recursive call short-circuits on the fast path. (Using
            // std::call_once here would deadlock — recursive call_once on
            // the same flag from the same thread is undefined behavior
            // and libc++ implements it as a hang.)
            initialized.store(true, std::memory_order_release);
            register_handler();
        }
    };
}


#endif //LIBMOBILEAGENT_LIBRARYCONTROLLER_HPP
