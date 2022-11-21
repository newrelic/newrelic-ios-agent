
#include <gmock/gmock.h>

#include <Connectivity/Facade.hpp>
#include <Utilities/Application.hpp>

namespace NewRelic {
namespace Connectivity {
class FacadeTest : public ::testing::Test {
protected:
    FacadeTest() : Test() {}

    virtual void SetUp() {
        Application::getInstance().setContext(ApplicationContext("accountId","applicationId"));
    }

    virtual void TearDown() {
        Application::getInstance().setContext(ApplicationContext("",""));
    }
};

TEST_F(FacadeTest, testFacade) {
   auto payload = Facade::getInstance().startTrip();
    ASSERT_TRUE(payload->getAccountId() == "accountId");
    ASSERT_TRUE(payload->getAppId() == "applicationId");
}

TEST_F(FacadeTest, testIdPersistence) {
    auto trip = Facade::getInstance().startTrip();
    auto payload = Facade::getInstance().newPayload();
    ASSERT_EQ(trip->getTraceId(), payload->getTraceId());
    auto newTrip = Facade::getInstance().startTrip();
    ASSERT_NE( newTrip->getTraceId(), trip->getTraceId());
    trip.release();
    ASSERT_NE(payload->getTraceId(),  newTrip->getTraceId());
    ASSERT_TRUE(trip.get() == nullptr);

    ASSERT_EQ(payload->getTraceId().length(), 16);
    ASSERT_EQ(payload->getId().length(), 16);
}

TEST_F(FacadeTest, testParentId) {
    auto trip = Facade::getInstance().startTrip();
    ASSERT_EQ(trip->getParentId(), "");
    auto payload1 = Facade::getInstance().newPayload();
    auto payload2 = Facade::getInstance().newPayload();
    ASSERT_EQ(payload1->getParentId(), trip->getId());
    ASSERT_EQ(payload2->getParentId(), trip->getId());
    trip.release();

    auto newTrip = Facade::getInstance().startTrip();
    ASSERT_NE(payload1->getParentId(),  newTrip->getId());
}

TEST_F(FacadeTest,testPayloadJson) {
    auto trip = Facade::getInstance().startTrip();
    auto json = trip->toJSON();
    auto data = json["d"];
    ASSERT_EQ(json["v"].type(), NRJSON::ARRAY);
    ASSERT_EQ(((NRJSON::JsonArray)json["v"]).size(), 2);
    ASSERT_EQ(data.type(), NRJSON::OBJECT);

    ASSERT_EQ(data["ac"].as_string(), "accountId");
    ASSERT_EQ(data["ap"].as_string(), "applicationId");
    ASSERT_EQ(data["ty"].as_string(), "Mobile");
    ASSERT_EQ(data["id"].type(), NRJSON::STRING);
    ASSERT_EQ(data["tr"].type(), NRJSON::STRING);
    ASSERT_EQ(data["ti"].type(), NRJSON::INT);

    ASSERT_EQ(data["ac"].as_string(), trip->getAccountId());
    ASSERT_EQ(data["ap"].as_string(), trip->getAppId());
    ASSERT_EQ(data["ty"].as_string(), trip->getType().getString());
    ASSERT_EQ(data["id"].as_string(), trip->getId());
    ASSERT_EQ(data["tr"].as_string(), trip->getTraceId());
    ASSERT_EQ(data["ti"].as_int(), trip->getTimestamp());

    auto payload = Facade::getInstance().newPayload();
    auto payloadJson = payload->toJSON();
    auto payloadData = (NRJSON::JsonObject)payloadJson["d"];

    ASSERT_EQ(((NRJSON::JsonArray)payloadJson["v"]).size(), 2);

    ASSERT_EQ(payloadData["ac"].as_string(), "accountId");
    ASSERT_EQ(payloadData["ap"].as_string(), "applicationId");
    ASSERT_EQ(payloadData["ty"].as_string(), "Mobile");
    ASSERT_EQ(payloadData["id"].type(), NRJSON::STRING);
    ASSERT_EQ(payloadData["tr"].type(), NRJSON::STRING);
    ASSERT_EQ(payloadData["ti"].type(), NRJSON::INT);
}
} // namespace Connectivity
} // namespace NewRelic
