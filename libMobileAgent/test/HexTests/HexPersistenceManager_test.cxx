//
// Created by Bryce Buchanan on 9/26/17.
//

#include <gmock/gmock.h>
#include <Hex/HexStore.hpp>
#include <Hex/HexPublisher.hpp>
#include <fstream>
#include <Analytics/AnalyticsController.hpp>
#include <Hex/HexPersistenceManager.hpp>
#include <Hex/HexController.hpp>
#include <Hex/generated/agent-data-bundle_generated.h>

using ::testing::_;
using namespace NewRelic;

const std::string TESTFILE("NRExceptionReport.fb");

class HexStoreTestChild : public NewRelic::Hex::HexStore {
public:
    HexStoreTestChild(const char* store) : HexStore(store) {}
    virtual std::string generateFilename() {
        return TESTFILE;
    }
};


class HexPersistenceManagerTest : public ::testing::Test {
public:
    PersistentStore<std::string, AnalyticEvent> eventStore;
    PersistentStore<std::string, BaseValue> attributeStore;
    Hex::HexPublisher* publisher;
    std::shared_ptr<Hex::HexStore> store;
    Hex::Report::ApplicationLicense applicationLicense;
    AnalyticsController* analyticsController;

    Hex::HexPersistenceManager persistenceManager;
    Hex::HexController hexController;
    const char* path = "";
    HexPersistenceManagerTest() :
            eventStore(AnalyticsController::getEventDupStoreName(),
                       "",
                       &EventManager::newEvent),
            attributeStore(AnalyticsController::getAttributeDupStoreName(),
                           "",
                           &Value::createValue),
            publisher(new Hex::HexPublisher("./persistenceManager")),
            store(std::make_shared<Hex::HexStore>("./persistenceManager")),
            applicationLicense("AAABBB123"),
            analyticsController(new AnalyticsController(0, "", eventStore, attributeStore)),
            persistenceManager{store,publisher},
            hexController(std::shared_ptr<AnalyticsController>(analyticsController),
                          std::make_shared<Hex::Report::AppInfo>(&applicationLicense,fbs::Platform_iOS),
                          publisher, store, "1")
    {}

    ~HexPersistenceManagerTest() {
        delete publisher;
    }

protected:
    virtual void SetUp() {
        mkpath_np("./persistenceManager",0770);
        remove(TESTFILE.c_str());
    }
    virtual void TearDown() {
        remove(TESTFILE.c_str());
    }
};

TEST_F(HexPersistenceManagerTest, testCountConsistency) {
    auto report1 = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                             std::vector<std::shared_ptr<Hex::Report::Thread>>());
    store->store(report1);

    auto report2 = hexController.createReport(1, "the tea is extremely hot", "really hot tea exception",
                                              std::vector<std::shared_ptr<Hex::Report::Thread>>());
    store->store(report2);

    auto response = persistenceManager.retrieveStoreReports();

    auto bundleData = GetAgentDataBundle(response->getBuilder()->GetBufferPointer());

    ASSERT_EQ(bundleData->agentData()->size(),2);

    //verify the files don't exist anymore
    response = persistenceManager.retrieveStoreReports();


    ASSERT_EQ(response, nullptr);

}

TEST_F(HexPersistenceManagerTest, testDataIntegrity) {
    auto report1 = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                              std::vector<std::shared_ptr<Hex::Report::Thread>>());
    store->store(report1);

    auto response = persistenceManager.retrieveStoreReports();

    auto bundleData = GetAgentDataBundle(response->getBuilder()->GetBufferPointer());

    ASSERT_EQ(bundleData->agentData()->size(),1);

    auto agentData = bundleData->agentData()->Get(0);

    ASSERT_TRUE(agentData->handledExceptions()->Get(0)->message()->str() == std::string("the tea is too hot"));
    ASSERT_TRUE(agentData->handledExceptions()->Get(0)->name()->str() == std::string("hot tea exception"));
    ASSERT_TRUE(agentData->handledExceptions()->Get(0)->timestampMs() == 1);


    //verify the files don't exist anymore
    response = persistenceManager.retrieveStoreReports();

    ASSERT_EQ(response,nullptr);

}


