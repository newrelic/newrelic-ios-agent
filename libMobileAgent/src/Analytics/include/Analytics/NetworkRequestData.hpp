//  Copyright © 2023 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_NETWORKREQUESTDATA_HPP
#define LIBMOBILEAGENT_NETWORKREQUESTDATA_HPP
#include <JSON/IJsonable.hpp>

namespace NewRelic {
    class NetworkRequestData {
    public:
        NetworkRequestData(const char* url,
                           const char* domain,
                           const char* path,
                           const char* method,
                           const char* connectionType,
                           const char* contentType,
                           unsigned int bytesSent);
        const char* getRequestUrl() const;
        const char* getRequestDomain() const;
        const char* getRequestPath() const;
        const char* getRequestMethod() const;
        const char* getConnectionType() const;
        const char* getContentType() const;
        unsigned int getBytesSent() const;
        
        std::map<std::string, std::string> getGraphQLHeaders() const;

        void setGraphQLHeaders(std::map<std::string, std::string> graphQLHeaders);

    private:
        const char *_requestUrl;
        const char *_requestDomain;
        const char *_requestPath;
        const char *_requestMethod;
        const char *_connectionType;
        const char *_contentType;
        unsigned int _bytesSent;
        // A dictionary to hold graphQL header information
        std::map<std::string, std::string> graphQLHeaders;
    };
}

#endif //LIBMOBILEAGENT_NETWORKREQUESTDATA_HPP
