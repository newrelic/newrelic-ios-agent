
#include <iostream>

#include <gmock/gmock.h>

#include "Utilities/Application.hpp"

using ::testing::Eq;

namespace NewRelic {

TEST(Application, testUnset) {
    auto application = Application::getInstance();

    ASSERT_EQ(application.getContext().getAccountId(), "");
    ASSERT_EQ(application.getContext().getApplicationId(), "");
}

TEST(Application, testSet) {
    auto application = Application::getInstance();
    application.setContext(ApplicationContext("accountId","applicationId"));
    ASSERT_EQ(application.getContext().getAccountId(), "accountId");
    ASSERT_EQ(application.getContext().getApplicationId(), "applicationId");
}

} // namespace NewRelic
