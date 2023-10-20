//  Copyright © 2023 New Relic. All rights reserved.

#import "Analytics/NetworkRequestData.hpp"

namespace NewRelic {

    NetworkRequestData::NetworkRequestData(const char *url,
                                           const char *domain,
                                           const char *path,
                                           const char *method,
                                           const char *connectionType,
                                           const char *contentType,
                                           unsigned int bytesSent) {
        _requestUrl = url;
        _requestDomain = domain;
        _requestPath = path;
        _requestMethod = method;
        _connectionType = connectionType;
        _contentType = contentType;
        _bytesSent = bytesSent;
    }

    const char* NetworkRequestData::getRequestUrl() const {
        return _requestUrl;
    }

    const char* NetworkRequestData::getRequestDomain() const {
        return _requestDomain;
    }

    const char* NetworkRequestData::getRequestPath() const {
        return _requestPath;
    }

    const char* NetworkRequestData::getRequestMethod() const {
        return _requestMethod;
    }

    const char* NetworkRequestData::getConnectionType() const {
        return _connectionType;
    }

    const char* NetworkRequestData::getContentType() const {
        return _contentType;
    }

    unsigned int NetworkRequestData::getBytesSent() const {
        return _bytesSent;
    }

    std::map<std::string, std::string> NetworkRequestData::getGraphQLHeaders() const {
        return graphQLHeaders;
    }

    void NetworkRequestData::setGraphQLHeaders(std::map<std::string, std::string> graphQLHeaders) {
        NetworkRequestData::graphQLHeaders = graphQLHeaders;
    }

}
