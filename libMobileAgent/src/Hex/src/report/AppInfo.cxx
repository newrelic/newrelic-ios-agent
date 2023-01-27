//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//
#include "ApplicationLicense.hpp"
#include "AppInfo.hpp"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

AppInfo::AppInfo(ApplicationLicense* appLicense,
                 fbs::Platform platform) : _appLicense(appLicense),
                                           _platform(platform) {}

Offset<fbs::ApplicationInfo> NewRelic::Hex::Report::AppInfo::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    auto serializedApplicationLicense = _appLicense->serialize(builder);
    return fbs::CreateApplicationInfo(builder,
                                      serializedApplicationLicense,
                                      _platform);
}
