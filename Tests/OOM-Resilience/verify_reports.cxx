//
//  verify_reports.cxx
//  Handled-exception OOM-resilience harness
//
//  Verifies that every persisted .fbad handled-exception report in a directory is
//  a well-formed HexAgentData flatbuffer, and reports the shapes it found.
//
//  Companion to hex_oom_harness. Surviving the OOM run is only half the contract;
//  the other half is that no half-written report reaches disk (and therefore the
//  collector). Before the issue #884 fix, a run at a 1-in-500 failure rate left
//  behind 0-byte files, reports truncated mid-library-list, and at least one
//  buffer the flatbuffers verifier rejected outright.
//
//  See Tests/OOM-RESILIENCE.md.
//

#include "hex-agent-data_generated.h"
#include <flatbuffers/flatbuffers.h>

#include <cstdio>
#include <cstdlib>
#include <dirent.h>
#include <fstream>
#include <map>
#include <string>
#include <vector>

int main(int argc, char** argv) {
    const char* dir = (argc > 1) ? argv[1] : ".";

    DIR* d = ::opendir(dir);
    if (!d) {
        std::printf("verify_reports: cannot open directory: %s\n", dir);
        return 2;
    }

    int valid = 0, invalid = 0, empty = 0;
    std::map<size_t, std::pair<int, size_t>> shapes;  // size -> (count, libraries)
    std::vector<std::string> rejected;

    struct dirent* entry = nullptr;
    while ((entry = ::readdir(d)) != nullptr) {
        std::string name{entry->d_name};
        const std::string ext = ".fbad";
        if (name.size() <= ext.size()) continue;
        if (name.compare(name.size() - ext.size(), ext.size(), ext) != 0) continue;

        const std::string path = std::string(dir) + "/" + name;
        std::ifstream f{path, std::ios::binary | std::ios::ate};
        if (!f.good()) { rejected.push_back(name + " (unreadable)"); ++invalid; continue; }

        const std::streamsize size = f.tellg();
        if (size <= 0) { ++empty; ++invalid; rejected.push_back(name + " (0 bytes)"); continue; }

        f.seekg(0);
        std::vector<uint8_t> buf(static_cast<size_t>(size));
        f.read(reinterpret_cast<char*>(buf.data()), size);

        flatbuffers::Verifier verifier(buf.data(), buf.size());
        if (!com::newrelic::mobile::fbs::VerifyHexAgentDataBuffer(verifier)) {
            ++invalid;
            rejected.push_back(name + " (" + std::to_string(size) + " bytes, failed verification)");
            continue;
        }

        size_t libraries = 0;
        const auto* agentData = com::newrelic::mobile::fbs::GetHexAgentData(buf.data());
        if (agentData && agentData->handledExceptions() && agentData->handledExceptions()->size() > 0) {
            const auto* handled = agentData->handledExceptions()->Get(0);
            if (handled && handled->libraries()) libraries = handled->libraries()->size();
        }
        ++valid;
        auto& shape = shapes[static_cast<size_t>(size)];
        shape.first++;
        shape.second = libraries;
    }
    ::closedir(d);

    std::printf("================ report verification ================\n");
    std::printf("directory : %s\n", dir);
    std::printf("valid     : %d\n", valid);
    for (const auto& kv : shapes) {
        std::printf("            %6zu bytes x%-6d -> %zu libraries\n",
                    kv.first, kv.second.first, kv.second.second);
    }
    std::printf("invalid   : %d", invalid);
    if (empty) std::printf("  (%d of them 0-byte)", empty);
    std::printf("\n");
    for (const auto& r : rejected) std::printf("            %s\n", r.c_str());

    if (valid == 0 && invalid == 0) {
        std::printf("RESULT: INCONCLUSIVE (no .fbad reports found)\n");
        return 3;
    }
    std::printf("RESULT: %s\n", invalid == 0 ? "PASS" : "FAIL");
    return invalid == 0 ? 0 : 1;
}
