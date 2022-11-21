//
// Created by Bryce Buchanan on 7/17/17.
//

#include <gmock/gmock.h>
#include <Hex/HexAuditor.hpp>
#include <Hex/HexPublisher.hpp>
#include <fstream>
#include <Analytics/AnalyticsController.hpp>
#include <Hex/HexController.hpp>

using ::testing::_;

using namespace NewRelic;

class HexAuditTest : public ::testing::Test {
public:
    PersistentStore<std::string, AnalyticEvent> eventStore;
    PersistentStore<std::string, BaseValue> attributeStore;
    Hex::HexPublisher* publisher;
    std::shared_ptr<Hex::HexStore> store;
    Hex::Report::ApplicationLicense applicationLicense;
    std::shared_ptr<AnalyticsController> analyticsController;
    Hex::HexController hexController;
    const char* path = "";

    HexAuditTest();

    ~HexAuditTest() {
        delete publisher;
    }
};

HexAuditTest::HexAuditTest() :
        eventStore(AnalyticsController::getEventDupStoreName(),
                   "",
                   &EventManager::newEvent),
        attributeStore{AnalyticsController::getAttributeDupStoreName(),
                       "",
                       &Value::createValue},
        publisher(new Hex::HexPublisher("")),
        store(std::make_shared<Hex::HexStore>("")),
        applicationLicense("AAABBB123"),
        analyticsController{std::make_shared<AnalyticsController>(0, "", eventStore, attributeStore)},
        hexController(std::shared_ptr<AnalyticsController>{analyticsController},
                      std::make_shared<Hex::Report::AppInfo>(&applicationLicense, fbs::Platform_iOS),
                      publisher, store, "1") {}

TEST_F(HexAuditTest, testAuditor) {
//    std::vector<std::shared_ptr<Hex::Report::Thread>> threads;
//    std::vector<Hex::Report::Frame> frames;
//    frames.push_back(Hex::Report::Frame("0\t0xDEADBEEF\t-[object message]:23\t(libMobileAgent.a)",1231234543323));
//    threads.push_back(std::make_shared<Hex::Report::Thread>(frames));
//    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception", threads);
//    flatbuffers::FlatBufferBuilder builder;
//    report->finalize(builder);
//
//
//
//    auto buf = builder.GetBufferPointer();
//    auto auditor = Hex::HexAuditor();
//    ASSERT_NO_THROW(auditor.audit(buf));

}
