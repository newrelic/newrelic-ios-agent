#include "Utilities/WorkQueue.hpp"
#include "Utilities/libLogger.hpp"

namespace NewRelic {

WorkQueue::WorkQueue() {
    _worker = std::thread(&WorkQueue::workerLoop, this);
}

void WorkQueue::workerLoop() {
    for (;;) {
        std::function<void()> task;
        {
            std::unique_lock<std::mutex> lk(_mutex);
            _cv.wait(lk, [this] { return _stopping || !_queue.empty(); });
            if (_stopping && _queue.empty())
                break;
            task = std::move(_queue.front());
            _queue.pop();
            _executing = true;
        }

        try {
            task();
        } catch (...) {
            // swallow or log
        }

        {
            std::lock_guard<std::mutex> lk(_mutex);
            _executing = false;
            if (_queue.empty())
                _emptyCv.notify_all();
        }
    }
}

void WorkQueue::enqueue(std::function<void()> workItem) {
    {
        std::lock_guard<std::mutex> lk(_mutex);
        if (_stopping) return;
        _queue.push(std::move(workItem));
    }
    _cv.notify_one();
}

bool WorkQueue::isEmpty() {
    std::lock_guard<std::mutex> lk(_mutex);
    return _queue.empty() && !_executing;
}

void WorkQueue::synchronize() {
    std::unique_lock<std::mutex> lk(_mutex);
    _emptyCv.wait(lk, [this]{ return _queue.empty() && !_executing; });
}

void WorkQueue::clearQueue() {
    std::lock_guard<std::mutex> lk(_mutex);
    std::queue<std::function<void()>> empty;
    std::swap(_queue, empty);
    if (_queue.empty() && !_executing)
        _emptyCv.notify_all();
}

void WorkQueue::terminate() {
    {
        std::lock_guard<std::mutex> lk(_mutex);
        if (_stopping) return;
        _stopping = true;
    }
    _cv.notify_all();
    if (_worker.joinable())
        _worker.join();
}

WorkQueue::~WorkQueue() {
    terminate();
}

} // namespace NewRelic
