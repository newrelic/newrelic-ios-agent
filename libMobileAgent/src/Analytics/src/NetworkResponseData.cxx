//  Copyright © 2023 New Relic. All rights reserved.

#import "Analytics/NetworkResponseData.hpp"

namespace NewRelic {
    NetworkResponseData::NetworkResponseData(unsigned int statusCode,
                                             unsigned int bytesReceived,
                                             double responseTime) : _encodedResponseBody(nullptr),
                                                                    _appDataHeader(nullptr),
                                                                    _responseTime(responseTime),
                                                                    _bytesReceived(bytesReceived),
                                                                    _statusCode(statusCode),
                                                                    _networkErrorMessage(nullptr),
                                                                    _networkErrorCode(0){}

    NetworkResponseData::NetworkResponseData(int networkErrorCode,
                                             unsigned int bytesReceived,
                                             double responseTime,
                                             const char *networkErrorMessage) : _encodedResponseBody(nullptr),
                                                                                _appDataHeader(nullptr),
                                                                                _responseTime(responseTime),
                                                                                _bytesReceived(bytesReceived),
                                                                                _statusCode(0),
                                                                                _networkErrorMessage(networkErrorMessage),
                                                                                _networkErrorCode(networkErrorCode) {}

    NetworkResponseData::NetworkResponseData(unsigned int statusCode,
                                             unsigned int bytesReceived,
                                             double responseTime,
                                             const char *networkErrorMessage,
                                             const char *encodedResponseBody,
                                             const char *appDataHeader) : _encodedResponseBody(encodedResponseBody),
                                                                          _appDataHeader(appDataHeader),
                                                                          _responseTime(responseTime),
                                                                          _bytesReceived(bytesReceived),
                                                                          _statusCode(statusCode),
                                                                          _networkErrorMessage(networkErrorMessage),
                                                                          _networkErrorCode(0) {}

    const char *NetworkResponseData::getEncodedResponseBody() const {
        return _encodedResponseBody;
    }

    const char *NetworkResponseData::getAppDataHeader() const {
        return _appDataHeader;
    }

    double NetworkResponseData::getResponseTime() const {
        return _responseTime;
    }

    unsigned int NetworkResponseData::getBytesReceived() const {
        return _bytesReceived;
    }

    unsigned int NetworkResponseData::getStatusCode() const {
        return _statusCode;
    }

    const char *NetworkResponseData::getNetworkErrorMessage() const {
        return _networkErrorMessage;
    }

    int NetworkResponseData::getNetworkErrorCode() const {
        return _networkErrorCode;
    }

}
