//
// Created by Bryce Buchanan on 9/21/17.
//

#include <gmock/gmock.h>
#include <Hex/HexStore.hpp>
#include <Hex/HexPublisher.hpp>
#include <fstream>
#include <atomic>
#include <chrono>
#include <thread>
#include <dirent.h>
#include <sys/stat.h>
#include <Analytics/AnalyticsController.hpp>
#include <Hex/HexController.hpp>

using ::testing::_;

using namespace NewRelic;

const std::string TESTFILE("NRExceptionReport.fb");

class HexStoreTestChild : public NewRelic::Hex::HexStore {
public:
    HexStoreTestChild(const char* store) : HexStore(store) {}
    virtual std::string generateFilename() {
        return storePath + '/' + TESTFILE;
    }

};

class HexStoreTest : public ::testing::Test {
public:
    PersistentStore<std::string, AnalyticEvent> eventStore;
    PersistentStore<std::string, BaseValue> attributeStore;
    Hex::HexPublisher* publisher;
    std::shared_ptr<Hex::HexStore> store;
    Hex::Report::ApplicationLicense applicationLicense;
    std::shared_ptr<AnalyticsController> analyticsController;
    Hex::HexController hexController;
    const char* path = "";
    HexStoreTest() :
            eventStore(AnalyticsController::getEventDupStoreName(),
                       "",
                       &EventManager::newEvent),
            attributeStore(AnalyticsController::getAttributeDupStoreName(),
                           "",
                           &Value::createValue),
            publisher(new Hex::HexPublisher(".")),
            store(std::make_shared<Hex::HexStore>(".")),
            applicationLicense("AAABBB123"),
            analyticsController(std::make_shared<AnalyticsController>(0, "", eventStore, attributeStore)),
            hexController(std::shared_ptr<AnalyticsController>(analyticsController),
                          std::make_shared<Hex::Report::AppInfo>(&applicationLicense,fbs::Platform_iOS),
                          publisher,store,"1")
    {}

    ~HexStoreTest() {
        delete publisher;
    }

protected:
    virtual void SetUp() {
        remove(TESTFILE.c_str());
    }
    virtual void TearDown() {
        remove(TESTFILE.c_str());
    }
};


TEST_F(HexStoreTest, testStoreLifeCycle) {
    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                             std::vector<std::shared_ptr<Hex::Report::Thread>>());

    HexStoreTestChild store(".");

    struct stat buffer;

    ASSERT_FALSE(stat (TESTFILE.c_str(), &buffer) == 0);

    store.store(report);

    ASSERT_TRUE(stat (TESTFILE.c_str(), &buffer) == 0);

    auto f = store.readAll([](uint8_t* buf, size_t size, const std::string& reportId) {
        ASSERT_TRUE(buf != NULL);
        auto agentData = GetAgentData(buf);
        ASSERT_TRUE(agentData != NULL);
    });

    f.get();

}

 TEST_F(HexStoreTest, testBadFolder) {
    auto report = hexController.createReport(1, "the tea is too hot", "hot tea exception",
                                             std::vector<std::shared_ptr<Hex::Report::Thread>>());
    mkpath_np("./inaccessible",0000);
    HexStoreTestChild store("./inaccessible");

    ASSERT_NO_THROW(store.store(report));
    auto f = store.readAll([](uint8_t* buf, size_t size, const std::string& reportId) {
        assert(false);
    });
    ASSERT_FALSE(f.get());
}

namespace {
    // Helpers reused by FD-pressure tests.
    std::size_t countFilesWithExtension(const std::string& dir, const std::string& ext) {
        DIR* dirp = opendir(dir.c_str());
        if (!dirp) return 0;
        std::size_t n = 0;
        struct dirent* dp = nullptr;
        while ((dp = readdir(dirp)) != nullptr) {
            std::string name{dp->d_name};
            if (name.length() > ext.length() &&
                name.compare(name.length() - ext.length(), ext.length(), ext) == 0) {
                ++n;
            }
        }
        closedir(dirp);
        return n;
    }

    void removeAllWithExtension(const std::string& dir, const std::string& ext) {
        DIR* dirp = opendir(dir.c_str());
        if (!dirp) return;
        struct dirent* dp = nullptr;
        while ((dp = readdir(dirp)) != nullptr) {
            std::string name{dp->d_name};
            if (name.length() > ext.length() &&
                name.compare(name.length() - ext.length(), ext.length(), ext) == 0) {
                std::string full = dir + "/" + name;
                std::remove(full.c_str());
            }
        }
        closedir(dirp);
    }
}

// On-disk backlog must not exceed the cap (kMaxBacklog = 100). Pre-seeds 110
// dummy .fbad files, calls store() once more, and asserts that no more than
// 100 files remain — this is the guard that prevents an indefinitely-offline
// app from accumulating thousands of cached reports and hitting EMFILE.
TEST_F(HexStoreTest, testBacklogCapEvictsOldest) {
    const std::string dir = "./hexbkup_capped";
    const std::string ext = ".fbad";
    mkpath_np(dir.c_str(), 0755);
    removeAllWithExtension(dir, ext);

    // Pre-seed 110 files with monotonically-increasing mtime so eviction
    // ordering by mtime is unambiguous.
    for (int i = 0; i < 110; ++i) {
        std::string filename = dir + "/NRExceptionReport" + std::to_string(i) + ext;
        std::ofstream f(filename, std::ios::binary);
        f << "x";
        f.close();
        // 10ms apart — guarantees distinct mtime even on coarse-grained FS.
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    ASSERT_EQ(countFilesWithExtension(dir, ext), 110u);

    auto report = hexController.createReport(1, "msg", "name",
                                             std::vector<std::shared_ptr<Hex::Report::Thread>>());
    NewRelic::Hex::HexStore capped(dir.c_str());
    capped.store(report);

    // Backlog must be at the cap (100). The 110 pre-seeded files were
    // evicted down to 99 + the new one we just stored = 100.
    std::size_t remaining = countFilesWithExtension(dir, ext);
    ASSERT_LE(remaining, 100u);

    // Cleanup.
    removeAllWithExtension(dir, ext);
    rmdir(dir.c_str());
}

// Corrupt / zero-byte .fbad files must be skipped, not crash. Previously
// HexStore::readAll fell through to `new uint8_t[size]` with size == -1
// when tellg() returned -1 on a corrupt file, allocating ~SIZE_MAX bytes.
TEST_F(HexStoreTest, testCorruptFileSkipped) {
    const std::string dir = "./hexbkup_corrupt";
    const std::string ext = ".fbad";
    mkpath_np(dir.c_str(), 0755);
    removeAllWithExtension(dir, ext);

    // Write one zero-byte (corrupt) file.
    std::string corruptPath = dir + "/NRExceptionReport_corrupt" + ext;
    std::ofstream(corruptPath).close();
    ASSERT_EQ(countFilesWithExtension(dir, ext), 1u);

    NewRelic::Hex::HexStore store(dir.c_str());
    std::atomic<int> callbackCount{0};
    auto f = store.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        callbackCount++;
    });
    ASSERT_TRUE(f.get());

    // Callback must not have fired for the corrupt file. The corrupt file
    // should also have been removed so it doesn't bounce forever.
    ASSERT_EQ(callbackCount.load(), 0);
    ASSERT_EQ(countFilesWithExtension(dir, ext), 0u);

    rmdir(dir.c_str());
}

// readAll() must NOT delete a valid report after handing it to the callback;
// the report is removed only once markUploaded() confirms its upload. This is
// the core "keep until confirmed" guarantee.
TEST_F(HexStoreTest, testReadAllKeepsReportUntilMarkedUploaded) {
    const std::string dir = "./hexbkup_keep";
    const std::string ext = ".fbad";
    mkpath_np(dir.c_str(), 0755);
    removeAllWithExtension(dir, ext);

    // A non-empty report file (readAll does not verify flatbuffer contents).
    std::string reportPath = dir + "/NRExceptionReport_keep" + ext;
    { std::ofstream f(reportPath, std::ios::binary); f << "report-bytes"; }
    ASSERT_EQ(countFilesWithExtension(dir, ext), 1u);

    NewRelic::Hex::HexStore store(dir.c_str());
    std::atomic<int> callbackCount{0};
    std::string capturedId;
    auto f = store.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        callbackCount++;
        capturedId = reportId;
    });
    ASSERT_TRUE(f.get());

    // Callback fired and the file is STILL on disk (not deleted by readAll).
    ASSERT_EQ(callbackCount.load(), 1);
    ASSERT_EQ(countFilesWithExtension(dir, ext), 1u);
    ASSERT_FALSE(capturedId.empty());

    // Confirming the upload deletes the file.
    store.markUploaded(capturedId);
    ASSERT_EQ(countFilesWithExtension(dir, ext), 0u);

    removeAllWithExtension(dir, ext);
    rmdir(dir.c_str());
}

// While a report is in flight (handed to the callback but not yet confirmed),
// a subsequent readAll() must skip it so it is not uploaded twice. markFailed()
// releases it so a later pass retries it.
TEST_F(HexStoreTest, testInFlightReportSkippedUntilReleased) {
    const std::string dir = "./hexbkup_inflight";
    const std::string ext = ".fbad";
    mkpath_np(dir.c_str(), 0755);
    removeAllWithExtension(dir, ext);

    std::string reportPath = dir + "/NRExceptionReport_inflight" + ext;
    { std::ofstream f(reportPath, std::ios::binary); f << "report-bytes"; }

    NewRelic::Hex::HexStore store(dir.c_str());

    // First pass marks the report in flight (callback does not confirm it).
    std::atomic<int> count1{0};
    std::string capturedId;
    auto f1 = store.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        count1++;
        capturedId = reportId;
    });
    ASSERT_TRUE(f1.get());
    ASSERT_EQ(count1.load(), 1);

    // Second pass must skip the still-in-flight report.
    std::atomic<int> count2{0};
    auto f2 = store.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        count2++;
    });
    ASSERT_TRUE(f2.get());
    ASSERT_EQ(count2.load(), 0);

    // Releasing it (upload not confirmed) lets the next pass pick it up again.
    store.markFailed(capturedId);
    std::atomic<int> count3{0};
    auto f3 = store.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        count3++;
    });
    ASSERT_TRUE(f3.get());
    ASSERT_EQ(count3.load(), 1);

    removeAllWithExtension(dir, ext);
    rmdir(dir.c_str());
}

// The in-flight claim is process-global, not per-HexStore: two HexStore instances over
// the SAME directory (as happens when the agent re-runs onSessionStart and creates a
// second NRMAHandledExceptions/HexStore on a foreground transition) must not BOTH read
// and upload the same report. This is the guard against duplicate uploads from double
// initialization.
TEST_F(HexStoreTest, testInFlightClaimSharedAcrossInstances) {
    const std::string dir = "./hexbkup_shared";
    const std::string ext = ".fbad";
    mkpath_np(dir.c_str(), 0755);
    removeAllWithExtension(dir, ext);

    std::string reportPath = dir + "/NRExceptionReport_shared" + ext;
    { std::ofstream f(reportPath, std::ios::binary); f << "report-bytes"; }

    NewRelic::Hex::HexStore storeA(dir.c_str());
    NewRelic::Hex::HexStore storeB(dir.c_str());

    std::atomic<int> countA{0};
    std::string capturedId;
    auto fA = storeA.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        countA++;
        capturedId = reportId;
    });
    ASSERT_TRUE(fA.get());
    ASSERT_EQ(countA.load(), 1);

    // Second instance must skip the report claimed (in-flight) by the first.
    std::atomic<int> countB{0};
    auto fB = storeB.readAll([&](uint8_t* buf, size_t size, const std::string& reportId) {
        countB++;
    });
    ASSERT_TRUE(fB.get());
    ASSERT_EQ(countB.load(), 0);

    // Resolving the claim deletes the file; neither instance uploaded it twice.
    storeA.markUploaded(capturedId);
    ASSERT_EQ(countFilesWithExtension(dir, ext), 0u);

    removeAllWithExtension(dir, ext);
    rmdir(dir.c_str());
}

