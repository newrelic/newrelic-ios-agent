//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Library.hpp"

NewRelic::Hex::Report::Library::Library(std::string name,
                                        uint64_t uuid_lo,
                                        uint64_t uuid_hi,
                                        uint64_t address,
                                        bool userLibrary,
                                        fbs::ios::Arch arch,
                                        uint64_t size
) : _name(name),
    _uuid_lo(uuid_lo),
    _uuid_hi(uuid_hi),
    _address(address),
    _userLibrary(userLibrary),
    _arch(arch),
    _size(size) {}

Offset<fbs::ios::Library> NewRelic::Hex::Report::Library::serialize(flatbuffers::FlatBufferBuilder& builder) const {

    return fbs::ios::CreateLibrary(builder, uuidLow(), uuidHigh(), _address, _userLibrary, _arch, getSize(), builder.CreateString(getName()));
}
