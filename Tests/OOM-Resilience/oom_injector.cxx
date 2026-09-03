//
//  oom_injector.cxx
//  Handled-exception OOM-resilience harness
//
//  Replaces global operator new so that 1-in-N allocations throw std::bad_alloc,
//  simulating the reporter's device in issue #884 / NR-614312 (~175 MiB free of
//  ~6.8 GiB in use). Loaded with SIMCTL_CHILD_DYLD_INSERT_LIBRARIES, so no agent
//  or app code has to change to run the test.
//
//  Two things keep the injection targeted at the path under test:
//
//    1. It arms NR_OOM_DELAY seconds after load, so app and agent startup run on
//       a healthy heap.
//    2. It only fails allocations on the thread named NR_OOM_THREAD (default
//       "nr-oom-loop"), which the NRTestApp driver names before it starts looping.
//       Without this the agent's harvest and upload threads also start throwing —
//       those are genuinely unguarded, but they are a different problem from #884
//       and their failures made this test flaky.
//
//  Env:
//    NR_OOM_ONE_IN   fail 1 in N allocations (default 1000; 0 disables)
//    NR_OOM_DELAY    seconds after load before arming (default 10)
//    NR_OOM_THREAD   only fail on this thread name (default "nr-oom-loop";
//                    set to "*" to fail process-wide)
//
//  See Tests/OOM-RESILIENCE.md.
//
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
#include <pthread.h>
#include <thread>

namespace {

std::atomic<bool> g_armed{false};
long              g_oneIn = 1000;
char              g_threadName[64] = "nr-oom-loop";
bool              g_anyThread = false;

// Plain integers so the thread_locals need no dynamic initialization — an
// allocating initializer here would recurse through operator new.
thread_local int      t_selected = -1;   // -1 unknown, 0 no, 1 yes
thread_local unsigned long long t_rng = 0;

bool threadIsSelected() {
    if (g_anyThread) return true;
    if (t_selected >= 0) return t_selected == 1;
    char name[64] = {0};
    if (pthread_getname_np(pthread_self(), name, sizeof(name)) != 0) {
        t_selected = 0;
        return false;
    }
    t_selected = (std::strcmp(name, g_threadName) == 0) ? 1 : 0;
    return t_selected == 1;
}

unsigned long long xorshift() {
    if (t_rng == 0) t_rng = 88442211ULL ^ (unsigned long long)(uintptr_t)&t_rng;
    t_rng ^= t_rng << 13;
    t_rng ^= t_rng >> 7;
    t_rng ^= t_rng << 17;
    return t_rng;
}

__attribute__((constructor))
void nr_oom_init() {
    if (const char* n = getenv("NR_OOM_ONE_IN")) g_oneIn = atol(n);
    if (const char* t = getenv("NR_OOM_THREAD")) {
        if (std::strcmp(t, "*") == 0) g_anyThread = true;
        else { std::strncpy(g_threadName, t, sizeof(g_threadName) - 1); }
    }
    long delay = 10;
    if (const char* d = getenv("NR_OOM_DELAY")) delay = atol(d);

    // stderr, not os_log: simctl launch --console captures stdio, so the runner
    // script can see these markers.
    std::fprintf(stderr, "[NR_OOM] injector loaded: 1-in-%ld on thread \"%s\", arming in %lds\n",
                 g_oneIn, g_anyThread ? "*" : g_threadName, delay);
    std::fflush(stderr);

    std::thread([delay]() {
        std::this_thread::sleep_for(std::chrono::seconds(delay));
        g_armed.store(true, std::memory_order_relaxed);
        std::fprintf(stderr, "[NR_OOM] ARMED\n");
        std::fflush(stderr);
    }).detach();
}

} // namespace

void* operator new(std::size_t n) {
    if (g_armed.load(std::memory_order_relaxed) && g_oneIn > 0 && threadIsSelected()) {
        if ((xorshift() % (unsigned long long)g_oneIn) == 0) throw std::bad_alloc();
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
