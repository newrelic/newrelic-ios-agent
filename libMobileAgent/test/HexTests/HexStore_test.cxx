//
// Created by Bryce Buchanan on 9/21/17.
//

#include <gmock/gmock.h>
#include <Hex/HexStore.hpp>
#include <Hex/HexPublisher.hpp>
#include <fstream>
#include <Analytics/AnalyticsController.hpp>
#include <Hex/HexController.hpp>

using ::testing::_;

using namespace NewRelic;

const std::string TESTFILE("NRExceptionReport.fb");

class HexStoreTestChild : public NewRelic::Hex::HexStore {
public:
    HexStoreTestChild(const char* store) : HexStore(store) {}
    virtual std::string generateFilename() {
        return storePath + '/' + TESTFILE;
    }

};

class HexStoreTest : public ::testing::Test {
public:
    PersistentStore<std::string, AnalyticEvent> eventStore;
    PersistentStore<std::string, BaseValue> attributeStore;
    Hex::HexPublisher* publisher;
    std::shared_ptr<Hex::HexStore> store;
    Hex::Report::ApplicationLicense applicationLicense;
    std::shared_ptr<AnalyticsController> analyticsController;
    Hex::HexController hexController;
    const char* path = "";
    HexStoreTest() :
            eventStore(AnalyticsController::getEventDupStoreName(),
                       "",
                       &EventManager::newEvent),
            attributeStore(AnalyticsController::getAttributeDupStoreName(),
                           "",
                           &Value::createValue),
            publisher(new Hex::HexPublisher(".")),
            store(std::make_shared<Hex::HexStore>(".")),
            applicationLicense("AAABBB123"),
            analyticsController(std::make_shared<AnalyticsController>(0, "", eventStore, attributeStore)),
            hexController(std::shared_ptr<AnalyticsController>(analyticsController),
                          std::make_shared<Hex::Report::AppInfo>(&applicationLicense,fbs::Platform_iOS),
                          publisher,store,"1")
    {}

    ~HexStoreTest() {
        delete publisher;
    }

protected:
    virtual void SetUp() {
        remove(TESTFILE.c_str());
    }
    virtual void TearDown() {
        remove(TESTFILE.c_str());
    }
};


TEST_F(HexStoreTest, testStoreLifeCycle) {
    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                             std::vector<std::shared_ptr<Hex::Report::Thread>>());

    HexStoreTestChild store(".");

    struct stat buffer;

    ASSERT_FALSE(stat (TESTFILE.c_str(), &buffer) == 0);

    store.store(report);

    ASSERT_TRUE(stat (TESTFILE.c_str(), &buffer) == 0);

    auto f = store.readAll([](uint8_t* buf, size_t size) {
        ASSERT_TRUE(buf != NULL);
        auto agentData = GetAgentData(buf);
        ASSERT_TRUE(agentData != NULL);
    });

    f.get();

}

 TEST_F(HexStoreTest, testBadFolder) {
    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                             std::vector<std::shared_ptr<Hex::Report::Thread>>());
    mkpath_np("./inaccessible",0000);
    HexStoreTestChild store("./inaccessible");

    ASSERT_NO_THROW(store.store(report));
    auto f = store.readAll([](uint8_t* buf, size_t size) {
        assert(false);
    });
    ASSERT_FALSE(f.get());
}

