//  Copyright © 2023 New Relic. All rights reserved.

#include "Utilities/ApplicationContext.hpp"

namespace NewRelic {

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>&
ApplicationContext::getAccountId() const {
    return accountId;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>&
ApplicationContext::getApplicationId() const {
    return applicationId;
}

ApplicationContext::ApplicationContext(
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>& accountId,
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>& applicationId)
        : accountId(accountId), applicationId(applicationId) {}

ApplicationContext::ApplicationContext(const std::string&& accountId, const std::string&& applicationId)
        : accountId(std::move(accountId)), applicationId(std::move(applicationId))
{}

} // namespace NewRelic
