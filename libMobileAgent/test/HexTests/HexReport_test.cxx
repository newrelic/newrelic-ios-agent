//
// Created by Bryce Buchanan on 6/30/17.
//

#include <gmock/gmock.h>
#include <Hex/HexPublisher.hpp>
#include <fstream>
#include <Analytics/AnalyticsController.hpp>
#include <Hex/HexController.hpp>

using ::testing::_;

using namespace NewRelic;


class HexContextTester : public ::testing::Test {
public:
    PersistentStore<std::string, AnalyticEvent> eventStore;
    PersistentStore<std::string, BaseValue> attributeStore;
    Hex::HexPublisher* publisher;
    std::shared_ptr<Hex::HexStore> store;
    Hex::Report::ApplicationLicense applicationLicense;
    std::shared_ptr<AnalyticsController> analyticsController;
    Hex::HexController hexController;
    const char* path = "";
    HexContextTester() :
            eventStore(AnalyticsController::getEventDupStoreName(),
                       "",
                       &EventManager::newEvent),
            attributeStore(AnalyticsController::getAttributeDupStoreName(),
                           "",
                           (std::shared_ptr<BaseValue>(*)(std::istream&))&Value::createValue),
            publisher(new Hex::HexPublisher(".")),
            store(std::make_shared<Hex::HexStore>(".")),
            applicationLicense("AAABBB123"),
            analyticsController(std::make_shared<AnalyticsController>(0, "", eventStore, attributeStore)),
            hexController(std::shared_ptr<AnalyticsController>(analyticsController),
                          std::make_shared<Hex::Report::AppInfo>(&applicationLicense,fbs::Platform_iOS),
                          publisher,
                          store,
                          "1")
    {}
    ~HexContextTester() {
        delete publisher;
    }

};


TEST_F(HexContextTester, testPublishMultiContext) {
    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                              std::vector<std::shared_ptr<Hex::Report::Thread>>());

    hexController.submit(report);

    report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                         std::vector<std::shared_ptr<Hex::Report::Thread>>());
    hexController.submit(report);

    hexController.publish();

}

TEST_F(HexContextTester, testCustomAttributes) {

    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                              std::vector<std::shared_ptr<Hex::Report::Thread>>());
    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 0);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 0);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 0);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 0);

    report->setAttribute("LongValue", 100LL);
    report->setAttribute("BoolValue", true);
    report->setAttribute("StringValue", "string");
    report->setAttribute("DoubleValue", 5.5);

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);

    ASSERT_NO_THROW(report->setAttribute("StringValue2", "")); //i will not be inserted

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);

    ASSERT_NO_THROW(report->setAttribute("", 300LL));

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);

    ASSERT_NO_THROW(report->setAttribute("", 15.0));

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);

    ASSERT_NO_THROW(report->setAttribute("", false));

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);
}

TEST_F(HexContextTester, testSessionAttributeOverride) {
    analyticsController->addSessionAttribute("LongValue", (long long) LONG_MAX);
    analyticsController->addSessionAttribute("DoubleValue", 1.0f);
    analyticsController->addSessionAttribute("BoolValue", false);
    analyticsController->addSessionAttribute("stringValue", "str");

    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                              std::vector<std::shared_ptr<Hex::Report::Thread>>());

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);

    auto boolMap = report->getBooleanAttributes()->get_attributes();
    auto strMap = report->getStringAttributes()->get_attributes();
    auto dblMap = report->getDoubleAttributes()->get_attributes();
    auto lngMap = report->getLongAttributes()->get_attributes();

    ASSERT_TRUE(boolMap["BoolValue"] == false);
    ASSERT_TRUE(strMap["stringValue"] == std::string("str"));
    ASSERT_TRUE(lngMap["LongValue"] == (long long)LONG_MAX);
    ASSERT_TRUE(dblMap["DoubleValue"] == 1.0f);

    report->setAttribute("LongValue",(long long)5);
    report->setAttribute("DoubleValue",(double)5.0f);
    report->setAttribute("BoolValue",true);
    report->setAttribute("stringValue","newStringValue");

    ASSERT_TRUE(report->getBooleanAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getLongAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getStringAttributes()->get_attributes().size() == 1);
    ASSERT_TRUE(report->getDoubleAttributes()->get_attributes().size() == 1);

    boolMap = report->getBooleanAttributes()->get_attributes();
    strMap = report->getStringAttributes()->get_attributes();
    dblMap = report->getDoubleAttributes()->get_attributes();
    lngMap = report->getLongAttributes()->get_attributes();

    ASSERT_TRUE(boolMap["BoolValue"] == true);
    ASSERT_TRUE(strMap["stringValue"] == std::string("newStringValue"));
    ASSERT_TRUE(lngMap["LongValue"] == (long long)5);
    ASSERT_TRUE(dblMap["DoubleValue"] == 5.0f);
}


