//  Copyright © 2023 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_NETWORKREQUESTDATA_HPP
#define LIBMOBILEAGENT_NETWORKREQUESTDATA_HPP
#include <string>
#include <map>

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
        
        std::map<std::string, std::string> getTrackedHeaders() const;

        void setTrackedHeaders(std::map<std::string, std::string> trackedHeaders);

    private:
        const char *_requestUrl;
        const char *_requestDomain;
        const char *_requestPath;
        const char *_requestMethod;
        const char *_connectionType;
        const char *_contentType;
        unsigned int _bytesSent;
        // A dictionary to hold the tracked header's information
        std::map<std::string, std::string> _trackedHeaders;
    };
}

#endif //LIBMOBILEAGENT_NETWORKREQUESTDATA_HPP
