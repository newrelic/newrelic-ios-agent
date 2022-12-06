//
// Created by Bryce Buchanan on 11/2/15.
//

#include <iostream>
#include <gmock/gmock.h>
using ::testing::Eq;

#include <Utilities/Value.hpp>
namespace NewRelic {

    TEST(Boolean, testBoolValue) {
        std::shared_ptr<Boolean> val = Value::createValue(true);
        EXPECT_EQ(true,val->getValue());
        auto val2 = Value::createValue(false);
        EXPECT_EQ(false,val2->getValue());
    }

    TEST(Boolean, serialize) {
        std::shared_ptr<Boolean> val = Value::createValue(true);
        std::stringstream os;
        os << (*val);
        auto val2 = Value::createValue(os);
        EXPECT_TRUE((*val) == *dynamic_cast<Boolean*>(val2.get()));
    }

}
