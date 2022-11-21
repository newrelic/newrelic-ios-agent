//
// Created by Jared Stanbrough on 6/26/17.
//

#import <iostream>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include "Library.hpp"
#include "Hex/LibraryController.hpp"
#include <Utilities/libLogger.hpp>

using namespace NewRelic::Hex::Report;

void NewRelic::LibraryController::register_handler() {
    auto handler = [](const struct mach_header* mh,
                      intptr_t vmaddr_slide) {

        Dl_info info;
        auto dladdr_ret = dladdr(mh, &info);

        if (dladdr_ret == 0) {
            perror(dlerror());
            return;
        }

        struct load_command* command = nullptr;
        int num_commands = 0;

        fbs::ios::Arch arch = fbs::ios::Arch::Arch_arm64;

        bool unknown = false;
        switch (mh->magic) {
            case MH_MAGIC:
            case MH_CIGAM:
                arch = fbs::ios::Arch::Arch_armv7;

                num_commands = mh->ncmds;
                command = (load_command*) (mh + 1);
                break;
            case MH_MAGIC_64:
            case MH_CIGAM_64: {
                const struct mach_header_64* mh64 = (mach_header_64*) mh;
                num_commands = mh64->ncmds;
                command = (load_command*) (mh64 + 1);
                break;
            }
            default:
                unknown = true;
        }

        if (unknown) {
            return;
        }

        uint64_t textSegmentSize = 0;
        uint8_t* uuid = nullptr;

        for (int command_index = 0; command_index < num_commands; command_index++) {

            // If we have both the text segment and uuid, we are done
            if (textSegmentSize != 0 && uuid != nullptr) {
                break;
            }

            // Look for the UUID
            if (command->cmd == LC_UUID && command->cmdsize == sizeof(uuid_command)) {
                auto uuid_command = (struct uuid_command*) command;
                uuid = uuid_command->uuid;
            }

            // Look for 32 bit and 64 bit segments. Ensure they are the __TEXT segment. Inlined for speed
            if (command->cmd == LC_SEGMENT) {
                auto segment_command = (struct segment_command*) command;
                const char* segname = segment_command->segname;
                if (segname[0] == '_' && segname[1] == '_' && segname[2] == 'T' && segname[3] == 'E' &&
                    segname[4] == 'X' && segname[5] == 'T') {
                    textSegmentSize = segment_command->vmsize;
                }
            }

            if (command->cmd == LC_SEGMENT_64) {
                auto segment_command64 = (struct segment_command_64*) command;
                char* segname = segment_command64->segname;
                if (segname[0] == '_' && segname[1] == '_' && segname[2] == 'T' && segname[3] == 'E' &&
                    segname[4] == 'X' && segname[5] == 'T') {
                    textSegmentSize = segment_command64->vmsize;
                }
            }
            command = (struct load_command*) ((uint8_t*) command + command->cmdsize);
        }

        auto address = (uint64_t) info.dli_fbase;
        if (uuid != nullptr && textSegmentSize != 0) {
            try {
                LibraryController::getInstance().add_library(info.dli_fname, uuid, address, arch, textSegmentSize);
            } catch (std::exception& e) {
                LLOG_ERROR("Failed to add library to Library Controller: %s", e.what());
            }
        }
    };

    _dyld_register_func_for_add_image(handler);
}

void NewRelic::LibraryController::add_library(const char* name,
                                              const uint8_t* uuid,
                                              uint64_t address,
                                              fbs::ios::Arch arch,
                                              uint64_t size) {
    bool userLibrary = false;
    auto name_string = std::string(name);
    for (auto& prefix : USER_LIBRARY_PATHS) {
        if (name_string.find(prefix) == 0) {
            userLibrary = true;
            break;
        }
    }

    uint64_t uuid_lo = uuid[0];

    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[1];
    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[2];
    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[3];
    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[4];
    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[5];
    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[6];
    uuid_lo = (uuid_lo << 8L) | (uint64_t) uuid[7];

    uint64_t uuid_hi = uuid[8];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[9];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[10];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[11];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[12];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[13];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[14];
    uuid_hi = (uuid_hi << 8L) | (uint64_t) uuid[15];

    Library library(name_string, uuid_lo, uuid_hi, address, userLibrary, arch, size);

    std::lock_guard<std::mutex> libraryLock(libraryContainerMutex);

    library_images.push_back(library);
}

