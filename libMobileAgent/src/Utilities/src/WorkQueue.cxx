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
        worker = std::async(std::launch::async, &WorkQueue::task_thread,this);
    }


    void WorkQueue::task_thread() {
        while (!shouldTerminate.load()) {
            {
                std::unique_lock<std::mutex> threadLock(_threadMutex);
                if (!queueReady) {
                    taskSignaler.wait(threadLock, [=] { return queueReady || shouldTerminate.load(); });
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

                } catch (...) {

                }

                executing.store(false);
            } else {
                queueReady = false;
                queueLock.unlock();
            }
        }
    }

    void WorkQueue::clearQueue() {
        std::lock_guard<std::recursive_mutex> queueLock(_queueMutex);
        std::queue<std::function<void(void)>> empty;
        std::swap(_queue,empty);
    }


    bool WorkQueue::isEmpty() {
        std::lock_guard<std::recursive_mutex> lk(_queueMutex);
        return _queue.empty();
    }
    void WorkQueue::synchronize() {
        while(!isEmpty() || executing.load()) {
            std::this_thread::sleep_for(std::chrono::duration<double,std::milli>(5));
        }
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
            //this is so we can consume the Future value (otherwise bad stuff happens)
            worker.get();
        }
    }

    WorkQueue::~WorkQueue() {
        terminate();
    }
}
