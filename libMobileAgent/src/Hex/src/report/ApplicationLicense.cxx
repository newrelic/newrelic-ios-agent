//
// Created by Bryce Buchanan on 6/13/17.
//

#include "ios_generated.h"
#include "hex_generated.h"
#include "session-attributes_generated.h"
#include "ApplicationLicense.hpp"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

ApplicationLicense::ApplicationLicense(const char* licenseKey) : _licenseKey(licenseKey) {}

Offset<fbs::ApplicationLicense> ApplicationLicense::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    auto licenseKey = builder.CreateString(_licenseKey);
    auto appLicenseBuilder = fbs::ApplicationLicenseBuilder(builder);
    appLicenseBuilder.add_licenseKey(licenseKey);
    return appLicenseBuilder.Finish();
}
