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

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>&
ApplicationContext::getTrustedAccountKey() const {
    return trustedAccountKey;
}

ApplicationContext::ApplicationContext(
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>& accountId,
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>& applicationId,
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>& trustedAccountKey)
        : accountId(accountId), applicationId(applicationId), trustedAccountKey(trustedAccountKey) {}

ApplicationContext::ApplicationContext(const std::string&& accountId, const std::string&& applicationId, const std::string&& trustedAccountKey)
        : accountId(std::move(accountId)), applicationId(std::move(applicationId)), trustedAccountKey(std::move(trustedAccountKey))
{}

} // namespace NewRelic
