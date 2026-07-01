//
// Created by Bryce Buchanan on 9/21/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_HEXSTORE_HPP
#define LIBMOBILEAGENT_HEXSTORE_HPP


#include <memory>
#include <string>
#include <future>
#include <functional>
#include <mutex>
#include <Hex/HexReport.hpp>

namespace NewRelic {
    namespace Hex {
        class HexStore {
        public:

            explicit HexStore(const char* storePath);

            void store(const std::shared_ptr<Report::HexReport>& report);

            /*
             * readAll()
             * executes callback closure on new thread with the flatbuffer data array
             * and the report's on-disk path (reportId) as parameters.
             *
             * Unlike the previous implementation, readAll() does NOT delete a report
             * after handing it to the callback. The report stays on disk and is marked
             * in-flight; the consumer must call markUploaded(reportId) once the upload
             * is confirmed (which deletes the file) or markFailed(reportId) to release
             * it for a later retry. Reports already in flight are skipped so a pending
             * upload is not read and re-sent on the next pass. A report whose upload is
             * never confirmed (e.g. the app is terminated mid-upload) therefore survives
             * on disk and is retried on the next launch.
             *
             * Corrupt / empty files are still removed inline since they can never upload.
             *
             * The uint8_t buffer param will be freed after the closure is complete.
             */
            std::future<bool> readAll(std::function<void(uint8_t*, std::size_t, const std::string& reportId)> callback);

            // Upload confirmed: delete the persisted report and clear its in-flight mark.
            void markUploaded(const std::string& reportId);

            // Upload not confirmed: clear the in-flight mark only, leaving the file on
            // disk so the next readAll() pass picks it up again.
            void markFailed(const std::string& reportId);

            void clear();

        protected:
            virtual std::string generateFilename();

            std::string storePath = ".";
            std::string filename = "";
        private:
            static const char* FILE_BASE;
            static const char* FILE_EXTENSION;
            mutable std::mutex _storeMutex;
            // NOTE: the set of reports currently in flight (handed to a publisher,
            // upload not yet resolved) is intentionally process-global rather than a
            // member here — see inFlightSet() in HexStore.cxx. Multiple HexStore
            // instances can exist over the same directory (the agent re-runs
            // onSessionStart on foreground transitions), and a per-instance set would
            // let each instance upload the same report. markUploaded()/markFailed()
            // resolve a claim in that global set.
        };
    }
}


#endif //LIBMOBILEAGENT_HEXSTORE_HPP
