//
//

#include <iostream>

#include <gmock/gmock.h>

#include <Utilities/UUID.hpp>

using ::testing::Eq;
using ::testing::_;

namespace NewRelic {

class MockUUID : public UUID, public testing::Test {
public:
    const uint16_t packedUUIDVersion = 0x4000;
    const uint16_t version_mask      = 0x0FFF; //top 4 bits reserved
    const uint16_t clk_seq_reserved  = 0x8000; //1000 0000 0000 0000
    const uint16_t clk_seq_mask      = 0x3FFF; //0011 1111 1111 1111 top two bits reserve
};

TEST_F(MockUUID, testUUID) {
    const uint32_t randomNumber      = 0x10101212;
    const uint16_t randomNumberHigh  = 0x1010;
    const uint16_t randomNumberLow   = 0x1212;

    auto uuid = UUID::createUUID([randomNumber]() -> uint32_t{
        return randomNumber;
    });


    ASSERT_TRUE(uuid.getTime_low() == randomNumber);
    ASSERT_TRUE(uuid.getTime_mid() == randomNumberHigh);

    uint16_t expectedHiAndVersion =  (packedUUIDVersion | (randomNumberLow & version_mask));

    ASSERT_TRUE(uuid.getTime_hi_and_version() == expectedHiAndVersion);

    uint16_t expectedClkSeq = clk_seq_reserved | (randomNumberLow & clk_seq_mask);
    ASSERT_TRUE(uuid.getClk_seq() ==  expectedClkSeq);
    ASSERT_TRUE(uuid.getNode0_1() == randomNumberHigh);
    ASSERT_TRUE(uuid.getNode2_5() == randomNumber);


   ASSERT_TRUE(uuid.toString()  == "10101212-1010-4212-9212-101010101212");
}

TEST_F(MockUUID,testUUIDagain) {
    const uint32_t randomNumber      = 0x00000000;
    const uint16_t randomNumberHigh  = 0x0000;
    const uint16_t randomNumberLow   = 0x0000;

    auto uuid = UUID::createUUID([randomNumber]() -> uint32_t{
        return randomNumber;
    });


    ASSERT_TRUE(uuid.getTime_low() == randomNumber);
    ASSERT_TRUE(uuid.getTime_mid() == randomNumberHigh);

    uint16_t expectedHiAndVersion =  (packedUUIDVersion | (randomNumberLow & version_mask));

    ASSERT_TRUE(uuid.getTime_hi_and_version() == expectedHiAndVersion);

    uint16_t expectedClkSeq = clk_seq_reserved | (randomNumberLow & clk_seq_mask);
    ASSERT_TRUE(uuid.getClk_seq() ==  expectedClkSeq);
    ASSERT_TRUE(uuid.getNode0_1() == randomNumberHigh);
    ASSERT_TRUE(uuid.getNode2_5() == randomNumber);


    ASSERT_TRUE(uuid.toString()  == "00000000-0000-4000-8000-000000000000");

}

TEST_F(MockUUID, testRandomness) {
    auto uuid = UUID::createUUID();
    ASSERT_TRUE(uuid.toString().length() == 36);
    ASSERT_TRUE(UUID::createUUID().toString().length() == UUID::createUUID().toString().length());

    for( int i = 0 ; i < 100000 ; i++) {
        auto uuid1 = UUID::createUUID().toString();
        auto uuid2 = UUID::createUUID().toString();
        ASSERT_NE(uuid1, uuid2);
    }
}

} // namespace NewRelic
