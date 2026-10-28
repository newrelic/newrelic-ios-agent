//
//  NRMAEventDuplicationStoreTests.mm
//  Agent_Tests
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Regression tests for NR-631296: the iOS watchdog (0x8BADF00D) killed apps whose
//  events buffer was full. The events duplication store's background writer held
//  the store's cache lock while it rewrote the whole file, a network thread inside
//  EventManager::addEvent held the events lock while it waited on that cache lock,
//  and the main thread waited on the events lock. Evictions also never removed
//  anything from the store (the key was built from the shared_ptr address), so the
//  file grew with every event and every eviction forced another full rewrite.
//

#import <XCTest/XCTest.h>
#import <Analytics/AnalyticsController.hpp>
#import <Analytics/EventManager.hpp>

#include <chrono>
#include <condition_variable>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <set>
#include <thread>
#include <vector>

using namespace NewRelic;

namespace {

typedef PersistentStore<std::string, AnalyticEvent> EventStore;

const unsigned long long kBaseTimestamp = 1759700000000ULL;
const std::chrono::milliseconds kWriterParkTimeout{5000};
const std::chrono::milliseconds kProducerBudget{1000};
const unsigned int kSynchronizeTimeoutMs = 5000;

// Serialization also runs on producer threads (EventManager::createKey builds the
// store key from the event), so only threads that never mark themselves as
// producers -- the store's background writer -- interact with the gate.
thread_local bool tl_isProducerThread = false;

// Parks the duplication store's background writer while it is serializing the
// file, standing in for the slow full-file rewrite in the customer's reports.
class WriterGate {
public:
    void writerSerializing() {
        std::unique_lock<std::mutex> lk(_mutex);
        _writerSerializations++;
        if (_released) {
            return;
        }
        _writerParked = true;
        _cv.notify_all();
        // Bounded so a regression can never hang the test run.
        _cv.wait_for(lk, std::chrono::seconds(10), [this] { return _released; });
    }

    bool waitForWriterToPark(std::chrono::milliseconds timeout) {
        std::unique_lock<std::mutex> lk(_mutex);
        return _cv.wait_for(lk, timeout, [this] { return _writerParked; });
    }

    void release() {
        std::lock_guard<std::mutex> lk(_mutex);
        _released = true;
        _cv.notify_all();
    }

    // Stands in for the iOS watchdog: the writer is let go after `timeout` at the latest.
    void releaseAfter(std::chrono::milliseconds timeout) {
        std::unique_lock<std::mutex> lk(_mutex);
        _cv.wait_for(lk, timeout, [this] { return _released; });
        _released = true;
        _cv.notify_all();
    }

    int writerSerializations() {
        std::lock_guard<std::mutex> lk(_mutex);
        return _writerSerializations;
    }

private:
    std::mutex _mutex;
    std::condition_variable _cv;
    bool _writerParked = false;
    bool _released = false;
    int _writerSerializations = 0;
};

AttributeValidator& permissiveValidator() {
    static AttributeValidator validator{[](const char*) { return true; },
                                        [](const char*) { return true; },
                                        [](const char*) { return true; }};
    return validator;
}

// Serializes exactly like a CustomEvent, so it round-trips through the store file,
// but parks the store's background writer on the gate while it is written.
class GatedEvent : public CustomEvent {
public:
    GatedEvent(std::shared_ptr<WriterGate> gate, unsigned long long timestamp_ms)
            : CustomEvent(std::make_shared<std::string>("GatedEvent"), timestamp_ms, 1, permissiveValidator()),
              _gate(gate) {}

    void put(std::ostream& os) const override {
        if (!tl_isProducerThread) {
            _gate->writerSerializing();
        }
        CustomEvent::put(os);
    }

private:
    std::shared_ptr<WriterGate> _gate;
};

// Runs `work` on its own producer thread. The thread is joined on destruction, so a
// test that sees it stall can release the gate first and still tear down cleanly.
class ProducerThread {
public:
    explicit ProducerThread(std::function<void()> work) : _done(_finished.get_future()) {
        _thread = std::thread([this, work] {
            tl_isProducerThread = true;
            work();
            _finished.set_value();
        });
    }

    ~ProducerThread() { join(); }

    bool finishedWithin(std::chrono::milliseconds timeout) {
        return _done.wait_for(timeout) == std::future_status::ready;
    }

    void join() {
        if (_thread.joinable()) {
            _thread.join();
        }
    }

private:
    std::promise<void> _finished;
    std::future<void> _done;
    std::thread _thread;
};

// The events duplication store exactly as NRMAAnalytics builds it: entries whose key
// does not match their event are dropped when the file is read back.
std::unique_ptr<EventStore> makeEventDupStore(const std::string& directory) {
    return std::unique_ptr<EventStore>(new EventStore(AnalyticsController::getEventDupStoreName(),
                                                      directory.c_str(),
                                                      &EventManager::newEvent,
                                                      [](std::string const& key, std::shared_ptr<AnalyticEvent> event) {
                                                          return key == EventManager::createKey(event);
                                                      }));
}

std::shared_ptr<AnalyticEvent> makeEvent(unsigned long long timestamp_ms) {
    return EventManager::newCustomEvent("DupStoreTestEvent", timestamp_ms, 1, permissiveValidator());
}

std::set<std::string> keysOf(const std::vector<std::shared_ptr<AnalyticEvent>>& events) {
    std::set<std::string> keys;
    for (const auto& event : events) {
        keys.insert(EventManager::createKey(event));
    }
    return keys;
}

std::set<std::string> cachedKeys(EventStore& store) {
    std::set<std::string> keys;
    for (const auto& entry : store.getCache()) {
        keys.insert(entry.first);
    }
    return keys;
}

// What a fresh launch reads back from disk, i.e. what crash recovery would send.
std::set<std::string> persistedKeys(const std::string& directory) {
    auto reader = makeEventDupStore(directory);
    return cachedKeys(*reader);
}

} // namespace

@interface NRMAEventDuplicationStoreTests : XCTestCase
@end

@implementation NRMAEventDuplicationStoreTests {
    std::string _directory;
}

- (void)setUp {
    [super setUp];
    // XCTest runs on the main thread, which plays the producer role in these tests.
    tl_isProducerThread = true;

    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"NRMAEventDuplicationStoreTests-%@", [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    _directory = directory.UTF8String;
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:@(_directory.c_str()) error:nil];
    tl_isProducerThread = false;
    [super tearDown];
}

- (void)testStoreAndRemoveDoNotWaitForAnInFlightWrite {
    auto store = makeEventDupStore(_directory);
    auto gate = std::make_shared<WriterGate>();
    auto gated = std::make_shared<GatedEvent>(gate, kBaseTimestamp);
    store->store(EventManager::createKey(gated), gated);
    XCTAssertTrue(gate->waitForWriterToPark(kWriterParkTimeout), @"the store was never written");

    auto first = makeEvent(kBaseTimestamp + 1);
    auto second = makeEvent(kBaseTimestamp + 2);
    ProducerThread producer([&] {
        store->store(EventManager::createKey(first), first);
        store->store(EventManager::createKey(second), second);
        store->remove(EventManager::createKey(first));
    });
    const bool finished = producer.finishedWithin(kProducerBudget);
    gate->release();
    producer.join();

    XCTAssertTrue(finished, @"store()/remove() waited for the background file write to finish");
    XCTAssertTrue(store->synchronize(kSynchronizeTimeoutMs));
    const std::set<std::string> expected{EventManager::createKey(gated), EventManager::createKey(second)};
    XCTAssertTrue(persistedKeys(_directory) == expected);
}

- (void)testMutationsDuringAWriteCoalesceIntoOneFollowUpWrite {
    auto store = makeEventDupStore(_directory);
    auto gate = std::make_shared<WriterGate>();
    auto gated = std::make_shared<GatedEvent>(gate, kBaseTimestamp);
    store->store(EventManager::createKey(gated), gated);
    XCTAssertTrue(gate->waitForWriterToPark(kWriterParkTimeout), @"the store was never written");

    // What a full buffer does on every insert: store the new event, remove an evicted one.
    std::vector<std::shared_ptr<AnalyticEvent>> events;
    for (unsigned long long i = 0; i < 200; i++) {
        events.push_back(makeEvent(kBaseTimestamp + 1 + i));
    }
    ProducerThread producer([&] {
        for (size_t i = 0; i < events.size(); i++) {
            store->store(EventManager::createKey(events[i]), events[i]);
            if (i > 0) {
                store->remove(EventManager::createKey(events[i - 1]));
            }
        }
    });
    const bool finished = producer.finishedWithin(kProducerBudget);
    gate->release();
    producer.join();

    XCTAssertTrue(finished, @"store()/remove() waited for the background file write to finish");
    XCTAssertTrue(store->synchronize(kSynchronizeTimeoutMs));
    // The parked write, plus one rewrite covering all 399 mutations, rather than a
    // full rewrite per call.
    XCTAssertEqual(gate->writerSerializations(), 2);
    const std::set<std::string> expected{EventManager::createKey(gated), EventManager::createKey(events.back())};
    XCTAssertTrue(persistedKeys(_directory) == expected);
}

- (void)testClearDuringAnInFlightWriteKeepsLaterEventsOnDisk {
    auto store = makeEventDupStore(_directory);
    auto gate = std::make_shared<WriterGate>();
    auto gated = std::make_shared<GatedEvent>(gate, kBaseTimestamp);
    store->store(EventManager::createKey(gated), gated);
    XCTAssertTrue(gate->waitForWriterToPark(kWriterParkTimeout), @"the store was never written");

    // A harvest clears the store while it is being written, and the next event arrives right after.
    auto afterHarvest = makeEvent(kBaseTimestamp + 1);
    ProducerThread producer([&] {
        store->clear();
        store->store(EventManager::createKey(afterHarvest), afterHarvest);
    });
    const bool finished = producer.finishedWithin(kProducerBudget);
    gate->release();
    producer.join();

    XCTAssertTrue(finished, @"clear()/store() waited for the background file write to finish");
    XCTAssertTrue(store->synchronize(kSynchronizeTimeoutMs));
    const std::set<std::string> expected{EventManager::createKey(afterHarvest)};
    XCTAssertTrue(persistedKeys(_directory) == expected);
}

- (void)testEveryMutationIsOnDiskOnceTheStoreIsSynchronized {
    auto store = makeEventDupStore(_directory);

    std::vector<std::shared_ptr<AnalyticEvent>> events;
    for (unsigned long long i = 0; i < 50; i++) {
        auto event = makeEvent(kBaseTimestamp + i);
        store->store(EventManager::createKey(event), event);
        events.push_back(event);
    }
    XCTAssertTrue(store->synchronize(kSynchronizeTimeoutMs));
    XCTAssertTrue(persistedKeys(_directory) == keysOf(events), @"events stored in a burst never reached the file");

    for (size_t i = 0; i < 25; i++) {
        store->remove(EventManager::createKey(events[i]));
    }
    XCTAssertTrue(store->synchronize(kSynchronizeTimeoutMs));
    XCTAssertTrue(persistedKeys(_directory) == keysOf(std::vector<std::shared_ptr<AnalyticEvent>>(events.begin() + 25, events.end())));

    store->clear();
    auto afterClear = makeEvent(kBaseTimestamp + 100);
    store->store(EventManager::createKey(afterClear), afterClear);
    XCTAssertTrue(store->synchronize(kSynchronizeTimeoutMs));
    const std::set<std::string> expected{EventManager::createKey(afterClear)};
    XCTAssertTrue(persistedKeys(_directory) == expected, @"an event stored right after clear() never reached the file");
}

@end
