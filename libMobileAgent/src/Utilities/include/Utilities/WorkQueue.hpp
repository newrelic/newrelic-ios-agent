#ifndef LIBMOBILEAGENT_WORKQUEUE_HPP
#define LIBMOBILEAGENT_WORKQUEUE_HPP

#pragma once
#include <queue>
#include <functional>
#include <future>
#include <mutex>
#include <condition_variable>
#include <atomic>

namespace NewRelic {
class WorkQueue {
public:
    WorkQueue();
    ~WorkQueue();

    void enqueue(std::function<void()> workItem);
    void clearQueue();
    bool isEmpty();
    void synchronize();          // Wait until all queued work finished (no timeout - CAUTION: may block indefinitely)
    bool synchronize(unsigned int timeout_ms);  // Wait with timeout, returns true if completed, false if timed out
    void terminate();            // Explicit shutdown (DEPRECATED: blocks indefinitely)
    bool terminate(unsigned int timeout_ms);    // Shutdown with timeout, returns true if joined, false if detached

private:
    void task_thread();

    std::queue<std::function<void()>> _queue;
    std::recursive_mutex _queueMutex;
    std::mutex _threadMutex;
    std::condition_variable taskSignaler;
    std::future<void> worker;
    std::atomic<bool> shouldTerminate;
    std::atomic<bool> executing;
    bool queueReady;
};
} // namespace NewRelic
#endif //LIBMOBILEAGENT_WORKQUEUE_HPP
