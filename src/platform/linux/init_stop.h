#pragma once

// Cooperative stop signal for the deferred-init wait loops.
//
// The attach poll (init.cpp) and the .data.rel.ro relocation waits
// (vtable_hook.cpp) run on the init thread, which OnUnload() joins so the
// process never unmaps code that thread is still executing. Without a way to
// tell that thread the process is exiting, the join sits through the remainder
// of the wait window -- which is what makes short-lived `steam` invocations
// (bootstrapper/updater, -shutdown, handover) take up to 120s to exit.
//
// The waits therefore sleep on this signal instead of usleep(): same interval,
// same iteration count, but they return at once when a stop is requested.

#include <atomic>
#include <chrono>
#include <thread>

namespace LinuxInitStop {

class StopSignal {
public:
    // Request a stop. Idempotent.
    void Request() {
        m_requested.store(true, std::memory_order_release);
    }

    bool Requested() const {
        return m_requested.load(std::memory_order_acquire);
    }

    // Sleep up to `interval`. Returns true if a stop was (or has been)
    // requested, false if the full interval elapsed without one.
    //
    // Polling instead of condition_variable::wait_for is deliberate: this
    // object is used from the ELF destructor, when libstdc++/glibc teardown
    // can no longer be assumed safe (the 32-bit join test crashed inside
    // pthread_cond_broadcast there). The stop latency is bounded by 10 ms.
    bool WaitFor(std::chrono::milliseconds interval) {
        const auto deadline = std::chrono::steady_clock::now() + interval;
        while (std::chrono::steady_clock::now() < deadline) {
            if (Requested()) return true;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        return Requested();
    }

private:
    std::atomic<bool> m_requested{false};
};

// Process-wide signal. Intentionally never destroyed: OnUnload() is an ELF
// destructor and runs after static destructors at process exit, so a signal
// with static storage duration could already be gone by the time it is set.
inline StopSignal& ProcessStop() {
    static StopSignal* signal = new StopSignal();
    return *signal;
}

enum class PollOutcome {
    Ready,      // probe() reported the awaited condition
    Stopped,    // a stop was requested (process is exiting)
    TimedOut,   // attempts exhausted without either
};

// Probe up to `attempts` times, sleeping `interval` on `stop` between probes.
// Worst case duration is attempts * interval, unchanged from a usleep() loop.
template <typename Probe>
inline PollOutcome PollUntilReady(StopSignal& stop, int attempts,
                                  std::chrono::milliseconds interval,
                                  Probe probe) {
    for (int i = 0; i < attempts; ++i) {
        if (probe()) return PollOutcome::Ready;
        if (stop.WaitFor(interval)) return PollOutcome::Stopped;
    }
    return PollOutcome::TimedOut;
}

} // namespace LinuxInitStop
