//
// Created by Bryce Buchanan on 2/22/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Utilities/WorkQueue.hpp"
#include "Utilities/libLogger.hpp"

namespace NewRelic {
    WorkQueue::WorkQueue()  : shouldTerminate(false),
                              executing(false),
                              queueReady(false) {
        worker = std::async(std::launch::async, &WorkQueue::task_thread, this);
    }


    void WorkQueue::task_thread() {
        while (!shouldTerminate.load()) {
            {
                std::unique_lock<std::mutex> threadLock(_threadMutex);
                if (!queueReady) {
                    taskSignaler.wait(threadLock, [this] { return queueReady || shouldTerminate.load(); });
                    continue;
                }
                threadLock.unlock();
            }
            std::unique_lock<std::recursive_mutex> queueLock(_queueMutex);
            if(!_queue.empty()) {
                auto f = _queue.front();
                _queue.pop();
                executing.store(true);
                queueLock.unlock();
                try {
                    f();
                } catch (std::exception& e) {
                    // swallow exceptions
                } catch (...) {
                    // swallow exceptions
                }

                executing.store(false);
                // Notify any waiting synchronize() calls
                taskSignaler.notify_all();
            } else {
                queueReady = false;
                queueLock.unlock();
            }
        }
    }

    void WorkQueue::clearQueue() {
        std::lock_guard<std::recursive_mutex> queueLock(_queueMutex);
        std::queue<std::function<void(void)>> empty;
        std::swap(_queue, empty);
    }


    bool WorkQueue::isEmpty() {
        std::lock_guard<std::recursive_mutex> lk(_queueMutex);
        return _queue.empty();
    }

    void WorkQueue::synchronize() {
        // Use condition variable wait instead of busy-wait loop
        std::unique_lock<std::mutex> threadLock(_threadMutex);
        taskSignaler.wait(threadLock, [this] {
            return isEmpty() && !executing.load();
        });
    }

    bool WorkQueue::synchronize(unsigned int timeout_ms) {
        // Wait with timeout using condition variable
        std::unique_lock<std::mutex> threadLock(_threadMutex);
        return taskSignaler.wait_for(
            threadLock,
            std::chrono::milliseconds(timeout_ms),
            [this] {
                return isEmpty() && !executing.load();
            }
        );
    }


    void WorkQueue::enqueue(std::function<void()> workItem){
        std::lock_guard<std::recursive_mutex> lk(_queueMutex);
        _queue.push(workItem);
        {
            std::lock_guard<std::mutex> _threadLock(_threadMutex);
            queueReady = true;
        }
        taskSignaler.notify_all();
    }


    void WorkQueue::terminate() {
        {
            std::lock_guard<std::mutex> _threadLock(_threadMutex);
            shouldTerminate.store(true);
        }
        taskSignaler.notify_all();

        if (worker.valid()) {
            // This blocks indefinitely - use with caution
            worker.get();
        }
    }

    bool WorkQueue::terminate(unsigned int timeout_ms) {
        {
            std::lock_guard<std::mutex> _threadLock(_threadMutex);
            shouldTerminate.store(true);
        }
        taskSignaler.notify_all();

        if (!worker.valid()) {
            return true;
        }

        // Wait for the future with timeout
        auto status = worker.wait_for(std::chrono::milliseconds(timeout_ms));

        if (status == std::future_status::ready) {
            // Worker completed, consume the future value
            worker.get();
            return true;
        } else {
            // Timeout occurred
            // Note: std::future cannot be detached like std::thread
            // The async task will continue running in the background
            LLOG_VERBOSE("WorkQueue terminate timed out after %u ms - worker will complete asynchronously", timeout_ms);
            return false;
        }
    }

    WorkQueue::~WorkQueue() {
        // Use timeout terminate to avoid indefinite blocking
        terminate(1000);

        // If worker is still valid (timeout occurred), we must wait for it
        // std::future destructor will block if the async result hasn't been retrieved
        if (worker.valid()) {
            LLOG_VERBOSE("WorkQueue destructor: worker still active, waiting for completion");
            try {
                worker.get();
            } catch (...) {
                // Ignore exceptions during cleanup
            }
        }
    }
}
