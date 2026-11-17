//
//  hex_oom_harness.cxx
//  Handled-exception OOM-resilience harness
//
//  Drives the real HexStore::store() -> HexReport::finalize() ->
//  AgentData::serialize() -> HandledException::serialize() path while making a
//  configurable fraction of heap allocations fail, simulating a device that is
//  nearly out of memory.
//
//  Written for GitHub issue #884 / NR-614312, where a std::bad_alloc raised
//  during handled-exception serialization unwound out of an Objective-C frame
//  with no handler above it and killed the host app.
//
//  It guards two distinct regressions:
//
//    1. A nested FlatBufferBuilder. Swallowing an exception thrown part-way
//       through a flatbuffer table (which HandledException.cxx used to do around
//       Library::serialize and Thread::serialize) leaves the builder with
//       nested_ == true. The next CreateString/CreateVector then trips
//       FLATBUFFERS_ASSERT(!nested). THIS HARNESS MUST BE COMPILED WITHOUT
//       NDEBUG so that assert is live -- it is the detector.
//
//    2. Invalid or truncated reports written to disk. Pair a run with
//       verify_reports to confirm every .fbad that survived is a well-formed
//       HexAgentData buffer.
//
//  See Tests/OOM-RESILIENCE.md.
//

#include <Hex/HexStore.hpp>
#include <Hex/HexReport.hpp>
#include <Hex/HandledException.hpp>
#include <Hex/AppInfo.hpp>
#include <Hex/ApplicationLicense.hpp>
#include <Analytics/AttributeValidator.hpp>

#include <atomic>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <exception>
#include <execinfo.h>
#include <memory>
#include <new>
#include <string>
#include <unistd.h>
#include <vector>

namespace {

std::atomic<bool>     g_armed{false};
std::atomic<long>     g_allocations{0};
std::atomic<long>     g_iteration{0};
std::atomic<long>     g_stored{0};
std::atomic<long>     g_dropped{0};

long     g_failOneIn = 1000;
bool     g_guard     = true;
uint64_t g_rng       = 88442211ULL;

uint64_t xorshift() {
    g_rng ^= g_rng << 13;
    g_rng ^= g_rng >> 7;
    g_rng ^= g_rng << 17;
    return g_rng;
}

// Reported when the process is about to die, so a regression names the frame it
// died in rather than just the exception type.
void onTerminate() {
    g_armed.store(false, std::memory_order_relaxed);
    std::printf("\n*** PROCESS KILLED by an uncaught C++ exception ***\n");
    std::printf("    on iteration %ld, after %ld allocations\n",
                g_iteration.load(), g_allocations.load());
    if (auto e = std::current_exception()) {
        try { std::rethrow_exception(e); }
        catch (const std::exception& ex) { std::printf("    exception: %s\n", ex.what()); }
        catch (...)                      { std::printf("    exception: <unknown>\n"); }
    }
    void* frames[48];
    int n = backtrace(frames, 48);
    std::printf("    backtrace (pipe through c++filt to demangle):\n");
    backtrace_symbols_fd(frames, n, 1);
    std::fflush(stdout);
    _exit(70);
}

// A flatbuffers FLATBUFFERS_ASSERT failure lands here, not in onTerminate.
// That is regression #1 above, so name it explicitly.
void onAbort(int) {
    std::printf("\n*** PROCESS ABORTED (assertion failure) ***\n");
    std::printf("    on iteration %ld, after %ld allocations\n",
                g_iteration.load(), g_allocations.load());
    std::printf("    A FLATBUFFERS_ASSERT(!nested) here means an exception was\n");
    std::printf("    swallowed part-way through building a flatbuffer table,\n");
    std::printf("    leaving the builder nested. See issue #884.\n");
    void* frames[48];
    int n = backtrace(frames, 48);
    std::printf("    backtrace (pipe through c++filt to demangle):\n");
    backtrace_symbols_fd(frames, n, 1);
    std::fflush(stdout);
    _exit(71);
}

void usage(const char* argv0) {
    std::printf(
        "usage: %s [options]\n"
        "\n"
        "  --fail-one-in N   Fail 1 in N heap allocations while the loop runs. Default 1000.\n"
        "                    0 disables injection entirely (sanity check).\n"
        "  --iterations N    recordError-equivalent calls to make. Default 50000.\n"
        "  --store DIR       Directory to write .fbad reports into. Default ./oom-store.\n"
        "  --no-guard        Do NOT wrap each call, mirroring an agent with no crash\n"
        "                    boundary. Expected to die; use it to show the boundary is\n"
        "                    load-bearing, not as a pass/fail test.\n"
        "  --seed N          PRNG seed, for reproducing a specific failure.\n"
        "  -h, --help        This message.\n"
        "\n"
        "exit: 0 survived, 70 uncaught exception, 71 assertion failure, 2 bad usage.\n",
        argv0);
}

} // namespace

// Replacing global operator new is how the low-memory device is simulated. The
// agent's C++ is statically linked into this binary, so its allocations come
// through here too.
void* operator new(std::size_t n) {
    if (g_armed.load(std::memory_order_relaxed)) {
        g_allocations.fetch_add(1, std::memory_order_relaxed);
        if (g_failOneIn > 0 && (xorshift() % static_cast<uint64_t>(g_failOneIn)) == 0) {
            throw std::bad_alloc();
        }
    }
    void* p = std::malloc(n ? n : 1);
    if (!p) throw std::bad_alloc();
    return p;
}
void* operator new[](std::size_t n) { return ::operator new(n); }
void* operator new(std::size_t n, const std::nothrow_t&) noexcept { return std::malloc(n ? n : 1); }
void* operator new[](std::size_t n, const std::nothrow_t&) noexcept { return std::malloc(n ? n : 1); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }
void operator delete(void* p, const std::nothrow_t&) noexcept { std::free(p); }
void operator delete[](void* p, const std::nothrow_t&) noexcept { std::free(p); }

using namespace NewRelic;
using namespace NewRelic::Hex;

int main(int argc, char** argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);

    long        iterations = 50000;
    std::string storeDir   = "./oom-store";

    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto next = [&](const char* what) -> const char* {
            if (i + 1 >= argc) { std::printf("missing value for %s\n", what); std::exit(2); }
            return argv[++i];
        };
        if      (a == "--fail-one-in") g_failOneIn = std::atol(next("--fail-one-in"));
        else if (a == "--iterations")  iterations  = std::atol(next("--iterations"));
        else if (a == "--store")       storeDir    = next("--store");
        else if (a == "--seed")        g_rng       = std::strtoull(next("--seed"), nullptr, 10);
        else if (a == "--no-guard")    g_guard     = false;
        else if (a == "-h" || a == "--help") { usage(argv[0]); return 0; }
        else { std::printf("unknown option: %s\n\n", a.c_str()); usage(argv[0]); return 2; }
    }

    std::set_terminate(onTerminate);
    signal(SIGABRT, onAbort);

    std::printf("handled-exception OOM resilience harness\n");
    std::printf("  store       : %s\n", storeDir.c_str());
    std::printf("  iterations  : %ld\n", iterations);
    std::printf("  failure rate: %s\n",
                g_failOneIn > 0 ? ("1 in " + std::to_string(g_failOneIn)).c_str() : "disabled");
    std::printf("  crash guard : %s\n\n", g_guard ? "on (mirrors NRMAHandledExceptions)" : "OFF");

    auto store = std::make_shared<HexStore>(storeDir.c_str());

    Report::ApplicationLicense license("AAABBB123");
    auto appInfo = std::make_shared<Report::AppInfo>(&license, fbs::Platform_iOS);
    NewRelic::AttributeValidator validator([](const char*){ return true; },
                                           [](const char*){ return true; },
                                           [](const char*){ return true; });

    // One recordError-equivalent: build the report, then serialize and persist it.
    auto once = [&](long i) {
        auto exception = std::make_shared<Report::HandledException>(
            "oom-harness-session",
            1700000000000ULL + static_cast<uint64_t>(i),
            "Flutter recordError",
            "PlatformException",
            std::vector<std::shared_ptr<Report::Thread>>{});
        auto report = std::make_shared<Report::HexReport>(exception, appInfo, validator);
        store->store(report);   // what HexController::submit() calls
    };

    g_armed.store(true, std::memory_order_relaxed);
    for (long i = 0; i < iterations; ++i) {
        g_iteration.store(i, std::memory_order_relaxed);
        if (g_guard) {
            // Mirrors the crash boundary in -[NRMAHandledExceptions recordError:attributes:].
            try {
                once(i);
                g_stored.fetch_add(1, std::memory_order_relaxed);
            } catch (...) {
                g_dropped.fetch_add(1, std::memory_order_relaxed);
            }
        } else {
            once(i);
            g_stored.fetch_add(1, std::memory_order_relaxed);
        }
    }
    g_armed.store(false, std::memory_order_relaxed);

    std::printf("SURVIVED %ld calls (%ld allocations)\n", iterations, g_allocations.load());
    std::printf("  reports stored : %ld\n", g_stored.load());
    std::printf("  reports dropped: %ld\n", g_dropped.load());
    std::printf("RESULT: PASS (no uncaught exception, no assertion failure)\n");
    return 0;
}
