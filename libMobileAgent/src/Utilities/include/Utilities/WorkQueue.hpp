#ifndef LIBMOBILEAGENT_WORKQUEUE_HPP
#define LIBMOBILEAGENT_WORKQUEUE_HPP

#pragma once
#include <queue>
#include <functional>
#include <thread>
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
    void synchronize();          // Wait until all queued work finished
    void terminate();            // Explicit shutdown

private:
    void workerLoop();

    std::queue<std::function<void()>> _queue;
    std::mutex _mutex;
    std::condition_variable _cv;         // work arrival or termination
    std::condition_variable _emptyCv;    // queue became empty
    std::thread _worker;
    bool _stopping{false};
    bool _executing{false};
};
} // namespace NewRelic
#endif //LIBMOBILEAGENT_WORKQUEUE_HPP
