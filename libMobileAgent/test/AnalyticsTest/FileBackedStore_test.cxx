
#include <Analytics/Stores/FileBackedStore.hpp>
#include <Analytics/EventManager.hpp>
#include <fstream>
#include <iostream>
#include <gmock/gmock.h>
using ::testing::Eq;
using ::testing::Test;


namespace NewRelic {

static const char* FILEBACKSTORE_TEMP_FILE = "fbstest_tempStore";

class FileBackedStoreTest: public ::testing::Test {

protected:
    FileBackedStoreTest() {}

    virtual ~FileBackedStoreTest() {}

    virtual void SetUp() {
        remove(FILEBACKSTORE_TEMP_FILE);
    }

    virtual void TearDown() {
        remove(FILEBACKSTORE_TEMP_FILE);
    }


};

TEST_F(FileBackedStoreTest, testStore) {
    FileBackedStore<std::string,std::string> fbs{FILEBACKSTORE_TEMP_FILE};

    fbs.store("key", std::make_shared<std::string>("value"));

    auto value = fbs.get("key");

    ASSERT_EQ(std::string("value"),*value);

    auto store = fbs.load();

    ASSERT_EQ(store.size(),1);

    ASSERT_EQ(std::string("value"),*store["key"]);

}

TEST_F(FileBackedStoreTest, testInvalidEvents) {

    FileBackedStore<std::string,AnalyticEvent> fbs{FILEBACKSTORE_TEMP_FILE, "", &EventManager::newEvent, [](std::string const& key, std::shared_ptr<AnalyticEvent> event){
        return key == EventManager::createKey(event);
    }};

    PersistentStore<std::string, AnalyticEvent> store{"tmp","",&EventManager::newEvent};
    EventManager eventManager{store};
    AttributeValidator validator{[](const char*){return true;},
                                 [](const char*){return true;},
                                 [](const char*){return true;}};

    auto event = eventManager.newRequestEvent(100,1,nullptr,validator);
    {
        std::stringstream ss;
        fbs.store(EventManager::createKey(event), event);
        fbs.flush();
        auto map = fbs.load();
        ASSERT_TRUE(map.size() == 1);
    }

    fbs.clear();
    {
        std::fstream file{FILEBACKSTORE_TEMP_FILE};
        file << EventManager::createKey(event) << std::endl;

        std::stringstream ss;
        ss << *event;
        //simulate a corrupted event
        file << ss.str().substr((unsigned long)ss.str().length()/2, ss.str().length());
        file.close();

        auto map = fbs.load();
        ASSERT_TRUE(map.size() == 0);
    }
}
} // namespace NewRelic
