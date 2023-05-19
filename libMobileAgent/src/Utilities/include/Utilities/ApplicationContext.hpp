//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_APPLICATIONCONTEXT_HPP
#define LIBMOBILEAGENT_APPLICATIONCONTEXT_HPP

#include <string>

namespace NewRelic {
class ApplicationContext {
private:
    std::string accountId;
    std::string applicationId;
    std::string trustedAccountKey;

public:
    ApplicationContext(const std::string& accountId, const std::string& applicationId, const std::string& trustedAccountKey);
    ApplicationContext(const std::string&& accountId, const std::string&& applicationId, const std::string&& trustedAccountKey);

    const std::string& getApplicationId() const;

    const std::string& getAccountId() const;

    const std::string& getTrustedAccountKey() const;

};
} // namespace NewRelic
#endif //LIBMOBILEAGENT_APPLICATIONCONTEXT_HPP
