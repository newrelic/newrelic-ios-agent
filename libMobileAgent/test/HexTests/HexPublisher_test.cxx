//
// Created by Bryce Buchanan on 6/16/17.
//

#include <gmock/gmock.h>
#include <Hex/HexPublisher.hpp>
#include <Hex/HexContext.hpp>
#include <fstream>
#include <Hex/generated/agent-data_generated.h>
#include <Hex/HexAuditor.hpp>
#include <Hex/HexReportContext.hpp>


using ::testing::Eq;
using ::testing::Test;
using namespace NewRelic::Hex;

class HexPublisherTester : public ::testing::Test {
public:
    std::string buildUUID;
    std::string sessionId;
    Report::HandledException exception;
    Report::ApplicationLicense applicationLicense;
    std::shared_ptr<Report::AppInfo> applicationInfo;

    HexPublisherTester() : buildUUID("0"),
                           sessionId("1"),
                           exception(sessionId,
                                     123,
                                     "the tea is too hot.",
                                     "HotTeaException",
                                     std::vector<std::shared_ptr<NewRelic::Hex::Report::Thread>>()),
                           applicationLicense("ABC123"),
                           applicationInfo(std::make_shared<Report::AppInfo>(&applicationLicense,com::newrelic::mobile::fbs::Platform_iOS))
     {}

};

TEST_F(HexPublisherTester, test) {
    NewRelic::Hex::HexPublisher publisher(".");
    auto context = std::make_shared<HexReportContext>(applicationInfo,
                                                NewRelic::AttributeValidator([](const char*){return true;},
                                                                             [](const char*){return true;},
                                                                             [](const char*){return true;}));

    std::string sessionId("sessionId!");
    auto exception = std::make_shared<Report::HandledException>(sessionId, 1, "The tea is too hot.", "HotTeaException", std::vector<std::shared_ptr<Report::Thread>>());
    auto report = context->createReport(exception);
    context->insert(report);
    ASSERT_NO_THROW(context->finalize());
    publisher.publish(context);


    std::ifstream f(publisher.lastPublishedFile().c_str(),std::ios::in|std::ios::binary);
    ASSERT_TRUE(f.good()); //assert the file exists

    char* buf = 0;
    f.seekg(0, std::ios::end);
    long long int length = f.tellg();
    f.seekg(0,std::ios::beg);
    buf = new char[length+1];
    f.read(buf,length);
    buf[length] = '\0';

    HexAuditor auditor;
    ASSERT_NO_THROW(auditor.audit((uint8_t*)buf));

    auto blah = com::newrelic::mobile::fbs::GetAgentDataBundle(buf);
    ASSERT_TRUE(blah->agentData()->Get(0)->handledExceptions()->Get(0)->name()->str() == "HotTeaException");
}
