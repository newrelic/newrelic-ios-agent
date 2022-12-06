//
// Created by Cameron Thomas on 4/24/15.
//

#include <Analytics/AnalyticsController.hpp>
#include <Analytics/Attribute.hpp>
#include <memory>
#include <gmock/gmock.h>
#include <ostream>
#include <list>
#include <numeric>
#include "PersistentStoreHelper.hpp"

using ::testing::Eq;
using ::testing::Test;

namespace NewRelic {

    class PersistentStoreTest : public ::testing::Test {
    public:
        unsigned long long epoch_time_ms;
        const char *storeName = "berry.attributes";

    protected:
        PersistentStoreTest() : Test(),
                                epoch_time_ms(
                                        (unsigned long long) std::chrono::duration_cast<std::chrono::milliseconds>(
                                                std::chrono::system_clock().now().time_since_epoch()).count()) {
        }

        virtual void TearDown() {
            remove(storeName);
        }

    };

    TEST_F(PersistentStoreTest, testPersistenceLoad) {
        PersistentStore<std::string, BaseValue> attribs(storeName, "", &Value::createValue);
        attribs.store("huckle", Value::createValue("berry"));
        attribs.synchronize();
        ASSERT_FALSE(PersistentStoreHelper::storeIsEmpty(storeName));

        auto map = attribs.load();
        ASSERT_EQ(map.size(), 1);

        PersistentStore<std::string, BaseValue> anotherStore(storeName, "", &Value::createValue);
        map = anotherStore.load();
        ASSERT_EQ(map.size(), 1);
        remove(storeName);
    }

    TEST_F(PersistentStoreTest, testPersistenceStoreAndReload) {
        PersistentStore<std::string, BaseValue> berryStore(storeName, "", &Value::createValue);
        PersistentStore<std::string, BaseValue> anotherBerryStore(storeName, "", &Value::createValue);
        auto berry = Value::createValue("berry");

        berryStore.store("huckle", berry);

        berryStore.synchronize();

        ASSERT_EQ(berryStore.load().size(), 1);

        auto loadedBerries = anotherBerryStore.load();
        ASSERT_EQ(loadedBerries.size(), 1);

        berryStore.store("marion", berry);
        berryStore.store("dingle", berry);
        berryStore.store("bumble", berry);

        berryStore.synchronize();

        loadedBerries = anotherBerryStore.load();
        ASSERT_EQ(loadedBerries.size(), 4);

        berryStore.clear();
        berryStore.synchronize();
        ASSERT_TRUE(berryStore.load().empty());

        loadedBerries = anotherBerryStore.load();
        ASSERT_TRUE(loadedBerries.empty());
        remove(storeName);
    }

    TEST_F(PersistentStoreTest, testPersistentEscapeCharacter) {
        PersistentStore<std::string, BaseValue> attribs(storeName, "", &Value::createValue);
        auto attribute = Attribute<const char*>::createAttribute("hell\t\n\a\boooo",[](const char*){return true;},"world\v\b\rasdf",[](const char*){return true;});
        attribs.store(attribute->getName(),attribute->getValue());
        attribs.synchronize();
        auto map = attribs.load();
        auto value = std::dynamic_pointer_cast<String>(map["hell\\t\\n\\a\\boooo"]);
        ASSERT_TRUE(value->getValue().compare("world\\v\\b\\rasdf") == 0);
        attribs.clear();
        remove(storeName);
    }

    TEST_F(PersistentStoreTest, testPersistenceIOTime) {
        unsigned int N_THREADS = 3;
        std::map<int, std::future<void>> threadMap;

        for (int t = 0; t < N_THREADS; t++) {
            try {
                threadMap[t] = std::async(std::launch::async, [t]() {
                    const std::string storeName = "berry" + std::to_string(t) + ".attributes";
                    unsigned int N_ATTRIBUTES = 64;
                    unsigned int N_ITERATIONS = 16;
                    try {
                        std::vector<long long> storeDurations;
                        std::vector<long long> loadDurations;

                        for (int i = 0; i < N_ITERATIONS; i++) {
                            remove(storeName.c_str());

                            auto tStart = std::chrono::high_resolution_clock::now();
                            PersistentStore<std::string, BaseValue> berryStore(storeName.c_str(), "",
                                                                               &Value::createValue);
                            auto berry = Value::createValue("berry");
                            for (int j = 0; j < N_ATTRIBUTES; j++) {
                                berryStore.store("attribute" + std::to_string(j), berry);
                                berryStore.synchronize();
                                auto map = berryStore.load();
                                ASSERT_EQ(j+1,map.size());

                            }


                            auto tEnd = std::chrono::high_resolution_clock::now();
                            auto tDelta = std::chrono::duration_cast<std::chrono::milliseconds>(tEnd - tStart);
                            // std::cout << N_ATTRIBUTES << " attributes written: " << tDelta.count() << " ms." << std::endl;
                            storeDurations.push_back(tDelta.count());

                            tStart = std::chrono::high_resolution_clock::now();
                            auto map = berryStore.load();
                            tEnd = std::chrono::high_resolution_clock::now();
                            tDelta = std::chrono::duration_cast<std::chrono::milliseconds>(tEnd - tStart);
                            // std::cout << map.size() << " attributes read: " << tDelta.count() << " ms." << std::endl;
                            loadDurations.push_back(tDelta.count());

                            remove(berryStore.getFullStorePath());
                        }

/*
                        std::cout << "Avg time for " << N_ATTRIBUTES << " attribute store operations was "
                        << (std::accumulate(storeDurations.begin(), storeDurations.end(), 0) / storeDurations.size())
                        << " ms." << std::endl;
                        std::cout << "Avg time for " << N_ATTRIBUTES << " attribute load operations was "
                        << (std::accumulate(loadDurations.begin(), loadDurations.end(), 0) / loadDurations.size())
                        << " ms." << std::endl;
*/

                    } catch (std::exception e) {
                        // no-op
                    }

                });
            } catch (std::system_error &error) {
                //todo: log messages / recover?
            }
        }

        for (auto it = threadMap.begin(); it != threadMap.end(); it++) {
            // std::cout << "Waiting on thread " << (*it).first << " ... ";
            (*it).second.wait();
            // std::cout << std::endl;
        }
    }

    TEST_F(PersistentStoreTest, testPersistenceSwap) {
        PersistentStore<std::string, BaseValue> berryStore(storeName, "", &Value::createValue);
        auto berry = Value::createValue("berry");

        berryStore.store("marion", berry);
        berryStore.store("dingle", berry);
        berryStore.store("bumble", berry);
        berryStore.store("straw", berry);
        berryStore.synchronize();
        auto map = berryStore.load();
        ASSERT_EQ(4, map.size());

        berryStore.swap();
        map = berryStore.load();
        ASSERT_TRUE(map.empty());

        ASSERT_TRUE(PersistentStoreHelper::storeExists(berryStore.getFullStorePath()));
        ASSERT_TRUE(PersistentStoreHelper::storeIsEmpty(berryStore.getFullStorePath()));

        std::string backupStorePath = std::string(berryStore.getFullStorePath()) + ".bak";
        ASSERT_TRUE(PersistentStoreHelper::storeExists(backupStorePath.c_str()));
    }

    TEST_F(PersistentStoreTest, testPersistenceBackupCleanup) {
        PersistentStore<std::string, BaseValue> berryStore(storeName, "", &Value::createValue);
        auto berry = Value::createValue("berry");

        berryStore.store("marion", berry);
        berryStore.synchronize();

        berryStore.swap();


        std::string backupStorePath = std::string(berryStore.getFullStorePath()) + ".bak";
        ASSERT_TRUE(PersistentStoreHelper::storeExists(backupStorePath.c_str()));

        // using the same filename will remove any backups in ctor
        PersistentStore<std::string, BaseValue> anotherBerryStore(storeName, "", &Value::createValue);
        ASSERT_FALSE(PersistentStoreHelper::storeExists(backupStorePath.c_str()));

        remove(backupStorePath.c_str());
    }

    TEST_F(PersistentStoreTest, testPersistenceAdd) {
        PersistentStore<std::string, BaseValue> berryStore(storeName, "", &Value::createValue);
        auto berry = Value::createValue("berry");

        berryStore.store("marion", berry);
        berryStore.synchronize();
        auto map = berryStore.load();
        ASSERT_EQ(1, map.size());

        PersistentStore<std::string, BaseValue> anotherBerryStore(storeName, "", &Value::createValue);
        map = anotherBerryStore.load();
        ASSERT_EQ(1, map.size());

        berryStore.store("dingle", berry);

        berryStore.synchronize();

        PersistentStore<std::string, BaseValue> anotherBerryStore2(storeName, "", &Value::createValue);
        map = anotherBerryStore2.load();
        ASSERT_EQ(2, map.size());

        remove(storeName);
    }

    TEST_F(PersistentStoreTest, testPersistenceRemove) {
        PersistentStore<std::string, BaseValue> berryStore(storeName, "", &Value::createValue);
        auto berry = Value::createValue("berry");

        berryStore.store("marion", berry);
        berryStore.store("dingle", berry);
        berryStore.store("bumble", berry);
        berryStore.store("straw", berry);
        berryStore.synchronize();

        auto map = berryStore.load();
        ASSERT_EQ(4, map.size());

        berryStore.remove("dingle");
        berryStore.synchronize();
        map = berryStore.load();
        ASSERT_EQ(3, map.size());

        PersistentStore<std::string, BaseValue> anotherBerryStore(storeName, "", &Value::createValue);
        map = anotherBerryStore.load();
        ASSERT_EQ(3, map.size());

        berryStore.remove("straw");
        berryStore.synchronize();
        map = berryStore.load();
        ASSERT_EQ(2, map.size());

        PersistentStore<std::string, BaseValue> anotherBerryStore2(storeName, "", &Value::createValue);
        map = anotherBerryStore2.load();
        ASSERT_EQ(2, map.size());

        remove(storeName);
    }

    TEST_F(PersistentStoreTest, testPersistenceClear) {
        PersistentStore<std::string, BaseValue> attribs(storeName, "", &Value::createValue);

        attribs.store("huckle", Value::createValue("berry"));

        attribs.synchronize();

        ASSERT_FALSE(PersistentStoreHelper::storeIsEmpty(storeName));

        attribs.clear();
        attribs.synchronize();

        ASSERT_TRUE(PersistentStoreHelper::storeIsEmpty(storeName));

        auto map = attribs.load();
        ASSERT_EQ(map.size(), 0);

        PersistentStore<std::string, BaseValue> anotherStore(storeName, "", &Value::createValue);
        map = anotherStore.load();
        ASSERT_EQ(map.size(), 0);
        remove(storeName);
    }

    TEST_F(PersistentStoreTest, testAsyncDestruction){
        PersistentStore<std::string,BaseValue> *attribs = new PersistentStore<std::string, BaseValue> (storeName, "", &Value::createValue);
        std::vector<std::thread> threads;
        for (int i = 0; i < 1000; i++) {
            threads.push_back(std::thread {[&attribs, i]() {
                if (attribs != NULL) {
                    attribs->store("blahblahblah", Value::createValue(i));
                }
            }
            });
        }
        auto tmp =  attribs;
        attribs = NULL;
        delete tmp;

        for(auto it = threads.begin() ; it != threads.end(); it++) {
            it->join();
        }
        remove(storeName);
    }
};

