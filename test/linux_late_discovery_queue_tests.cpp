#include "late_discovery_queue.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>

using namespace std::chrono_literals;

static int g_failures = 0;

#define CHECK(cond, message) do { \
    if (!(cond)) { \
        std::fprintf(stderr, "FAIL: %s\n", message); \
        ++g_failures; \
    } \
} while (0)

static void TestFifoAndDeduplication() {
    LinuxLateDiscovery::Queue queue;
    CHECK(queue.Enqueue(30), "first app must be accepted");
    CHECK(queue.Enqueue(10), "second app must be accepted");
    CHECK(!queue.Enqueue(30), "duplicate app must be rejected");
    CHECK(!queue.Enqueue(0), "zero app id must be rejected");

    uint32_t appId = 0;
    CHECK(queue.TryPop(appId) && appId == 30,
          "queue must preserve discovery order");
    CHECK(queue.TryPop(appId) && appId == 10,
          "queue must preserve discovery order after a duplicate");
    CHECK(!queue.TryPop(appId), "empty queue must not produce an item");
}

static void TestSingleConsumerHandlesLargeBurst() {
    LinuxLateDiscovery::Queue queue;
    std::vector<uint32_t> processed;
    processed.reserve(10000);
    std::mutex processedMutex;
    std::condition_variable processedCv;
    std::atomic<int> activeHandlers{0};
    std::atomic<int> maxActiveHandlers{0};

    std::thread worker([&] {
        LinuxLateDiscovery::Drain(
            queue,
            [&](uint32_t appId) {
                const int active = activeHandlers.fetch_add(1) + 1;
                int observed = maxActiveHandlers.load();
                while (active > observed &&
                       !maxActiveHandlers.compare_exchange_weak(observed, active)) {}
                {
                    std::lock_guard<std::mutex> lock(processedMutex);
                    processed.push_back(appId);
                }
                activeHandlers.fetch_sub(1);
                processedCv.notify_all();
            },
            [](uint32_t) {});
    });

    for (uint32_t appId = 1; appId <= 10000; ++appId)
        CHECK(queue.Enqueue(appId), "every unique app in a burst must be accepted");

    {
        std::unique_lock<std::mutex> lock(processedMutex);
        CHECK(processedCv.wait_for(lock, 5s, [&] { return processed.size() == 10000; }),
              "single consumer must drain the complete burst");
    }
    queue.Stop();
    worker.join();

    CHECK(processed.size() == 10000,
          "large burst must not lose discovered apps");
    CHECK(maxActiveHandlers.load() == 1,
          "large burst must never execute handlers concurrently");
    if (processed.size() == 10000) {
        for (uint32_t index = 0; index < processed.size(); ++index) {
            if (processed[index] != index + 1) {
                CHECK(false, "large burst must retain FIFO order");
                break;
            }
        }
    }
}

static void TestHandlerFailureDoesNotStopDrain() {
    LinuxLateDiscovery::Queue queue;
    std::vector<uint32_t> processed;
    std::vector<uint32_t> failed;
    std::mutex mutex;
    std::condition_variable cv;

    std::thread worker([&] {
        LinuxLateDiscovery::Drain(
            queue,
            [&](uint32_t appId) {
                if (appId == 2) throw std::runtime_error("fixture failure");
                std::lock_guard<std::mutex> lock(mutex);
                processed.push_back(appId);
                cv.notify_all();
            },
            [&](uint32_t appId) {
                std::lock_guard<std::mutex> lock(mutex);
                failed.push_back(appId);
                cv.notify_all();
            });
    });

    queue.Enqueue(1);
    queue.Enqueue(2);
    queue.Enqueue(3);
    {
        std::unique_lock<std::mutex> lock(mutex);
        CHECK(cv.wait_for(lock, 2s, [&] {
            return processed.size() == 2 && failed.size() == 1;
        }), "drain must continue after one app handler throws");
    }
    queue.Stop();
    worker.join();

    CHECK(processed == std::vector<uint32_t>({1, 3}),
          "apps around a failed item must still be processed in order");
    CHECK(failed == std::vector<uint32_t>({2}),
          "failure callback must identify only the failed app");
}

static void TestStopWakesWaiterAndRejectsNewWork() {
    LinuxLateDiscovery::Queue queue;
    std::atomic<bool> exited{false};
    std::thread worker([&] {
        uint32_t appId = 0;
        CHECK(!queue.WaitPop(appId),
              "stopped empty queue must wake without an item");
        exited.store(true);
    });

    std::this_thread::sleep_for(20ms);
    queue.Stop();
    worker.join();

    CHECK(exited.load(), "stop must wake the blocked consumer");
    CHECK(!queue.Enqueue(42), "stopped queue must reject new discoveries");
}

static void TestStopDiscardsPendingWork() {
    LinuxLateDiscovery::Queue queue;
    queue.Enqueue(1);
    queue.Enqueue(2);
    queue.Stop();

    uint32_t appId = 0;
    CHECK(!queue.TryPop(appId),
          "shutdown must discard work that has not started");
    CHECK(queue.Pending() == 0,
          "shutdown must release pending app ids");
}

int main() {
    TestFifoAndDeduplication();
    TestSingleConsumerHandlesLargeBurst();
    TestHandlerFailureDoesNotStopDrain();
    TestStopWakesWaiterAndRejectsNewWork();
    TestStopDiscardsPendingWork();

    if (g_failures != 0) {
        std::fprintf(stderr, "%d test(s) failed\n", g_failures);
        return 1;
    }
    std::puts("linux late discovery queue tests passed");
    return 0;
}
