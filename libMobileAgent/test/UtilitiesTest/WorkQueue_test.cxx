//
// Created by Bryce Buchanan on 2/22/16.
//

#include <iostream>
#include <future>
#include <gmock/gmock.h>

using ::testing::Eq;

#include <Utilities/WorkQueue.hpp>
#include <sys/proc_info.h>

namespace NewRelic {


    TEST(WorkQueue, testThreadSafeAndOrdered) {
        WorkQueue* workqueue = new WorkQueue();
        int* i = new int(0);

        workqueue->enqueue([=]{
            while ((*i) < 10) {
                (*i) +=1;
            }
        });

        workqueue->enqueue([=]{
            (*i) *= 2;
        });

        std::async(std::launch::async,[=](){
            workqueue->enqueue([=]{
                (*i) = (*i)*2;
            });
        });

         workqueue->synchronize();

        for (int i = 0; i < 100;i++) {
               workqueue->enqueue([]{
                   std::this_thread::sleep_for(std::chrono::milliseconds(1));
               });
        }

        ASSERT_NO_THROW(delete workqueue); //there are still items in the queue; too bad.

        ASSERT_EQ((*i) , (10 * 4));
    }
    TEST(WorkQueue, testExceptionHandling) {
        WorkQueue queue;
        queue.enqueue([] {
            throw 8;
        });
        queue.synchronize();
        ASSERT_TRUE(queue.isEmpty());
    }

    TEST(WorkQueue,testEmpty) {

        WorkQueue queue;

        for (int i = 0; i < 100;i++) {
            queue.enqueue([]{
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            });
        }

        queue.clearQueue();
        ASSERT_TRUE(queue.isEmpty());
    }
}
