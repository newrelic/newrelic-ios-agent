#include <iostream>
#include <gmock/gmock.h>
using ::testing::Eq;

#include <Utilities/Value.hpp>
namespace  NewRelic {

    TEST(Number, testFloatValue) {
        auto num = Value::createValue(2.82f);
        EXPECT_EQ(2.82f, num->doubleValue());
        EXPECT_EQ(2, num->longLongValue());
        EXPECT_EQ(2, num->unsignedLongLongValue());
    }
    TEST(Number, testLongValue) {
        auto num = Value::createValue(UINT64_MAX);
        EXPECT_EQ(UINT64_MAX,num->unsignedLongLongValue());
        EXPECT_EQ(-1, num->longLongValue());
        EXPECT_EQ(UINT64_MAX,num->doubleValue());
    }

    TEST(Number, testUnsignedLongValue) {
        auto num = Value::createValue(-12345);
        EXPECT_EQ(-12345, num->longLongValue());
        EXPECT_EQ(-12345,num->doubleValue());
        EXPECT_EQ((__uint64_t)-12345,num->longLongValue());
    }
    TEST(Number, serialize) {
        std::shared_ptr<Number> num = Value::createValue(100);
        std::stringstream os;
        os << (*num);

        auto num2 = Value::createValue(os);

        EXPECT_TRUE((*num)==*dynamic_cast<Number*>(num2.get()));

    }

}


