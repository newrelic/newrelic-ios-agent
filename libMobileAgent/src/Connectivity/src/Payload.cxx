//  Copyright © 2023 New Relic. All rights reserved.

#include <Connectivity/Payload.hpp>


const std::__1::vector<int> &NewRelic::Connectivity::Payload::getVersion() const {
    return version;
}

void NewRelic::Connectivity::Payload::setVersion(const std::__1::vector<int> &version) {
    Payload::version = version;
}

const NewRelic::Connectivity::PayloadType &NewRelic::Connectivity::Payload::getType() const {
    return type;
}

void NewRelic::Connectivity::Payload::setType(const NewRelic::Connectivity::PayloadType &type) {
    Payload::type = type;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &
NewRelic::Connectivity::Payload::getAccountId() const {
    return accountId;
}

void NewRelic::Connectivity::Payload::setAccountId(
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &accountId) {
    Payload::accountId = accountId;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &
NewRelic::Connectivity::Payload::getAppId() const {
    return appId;
}

void NewRelic::Connectivity::Payload::setAppId(
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &appId) {
    Payload::appId = appId;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &
NewRelic::Connectivity::Payload::getId() const {
    return id;
}

void NewRelic::Connectivity::Payload::setId(
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &id) {
    Payload::id = id;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &
NewRelic::Connectivity::Payload::getTraceId() const {
    return traceId;
}

void NewRelic::Connectivity::Payload::setTraceId(
        const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>& traceId) {
    Payload::traceId = traceId;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &NewRelic::Connectivity::Payload::getParentId() const {
    return parentId;
}

void NewRelic::Connectivity::Payload::setParentId(const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &parentId) {
    Payload::parentId = parentId;
}

const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &NewRelic::Connectivity::Payload::getTrustedAccountKey() const {
    return trustedAccountKey;
}

void NewRelic::Connectivity::Payload::setTrustedAccountKey(const std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>> &trustedAccountKey) {
    Payload::trustedAccountKey = trustedAccountKey;
}

long long int NewRelic::Connectivity::Payload::getTimestamp() const {
    return timestamp;
}

void NewRelic::Connectivity::Payload::setTimestamp(long long int timestamp) {
    Payload::timestamp = timestamp;
}

bool NewRelic::Connectivity::Payload::getDistributedTracing() const {
    return dtEnabled;
}

void NewRelic::Connectivity::Payload::setDistributedTracing(bool enabled) {
    Payload::dtEnabled = enabled;
}

NRJSON::JsonObject NewRelic::Connectivity::Payload::toJSON() {
    NRJSON::JsonObject json{};
    static const std::string versionKey   = "v";
    static const std::string dataKey      = "d";
    static const std::string typeKey      = "ty";
    static const std::string accountKey   = "ac";
    static const std::string appKey       = "ap";
    static const std::string idKey        = "id";
    static const std::string traceKey     = "tr";
    static const std::string timeKey      = "ti";
    static const std::string trustKey     = "tk";

    NRJSON::JsonArray versionArray;
    for (auto it = version.cbegin(); it != version.cend(); it++){
        versionArray.push_back(NRJSON::JsonValue(*it));
    }

    NRJSON::JsonObject data;
    data[typeKey] = NRJSON::JsonValue(type.getString());
    data[accountKey] = NRJSON::JsonValue(accountId);
    data[appKey] = NRJSON::JsonValue(appId);
    data[idKey] = NRJSON::JsonValue(id);
    data[traceKey] = NRJSON::JsonValue(traceId);
    data[timeKey]  = NRJSON::JsonValue(timestamp);

    if (trustedAccountKey.length() > 0 && accountId != trustedAccountKey) {
        data[trustKey] = NRJSON::JsonValue(trustedAccountKey);
    }

    json[versionKey] = versionArray;
    json[dataKey] = data;

    return json;
}
