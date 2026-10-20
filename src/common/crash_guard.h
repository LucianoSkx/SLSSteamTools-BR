#pragma once

// Crash guard for calls into steamclient.so whose entry points are found by
// signature scan. A stale signature can fault mid-call; instead of taking the
// Steam client down, SIGSEGV/SIGBUS becomes a longjmp back to the caller,
// which degrades (skips the call, logs) rather than crashing.
//
// One handler is installed process-wide for as long as any guard is alive,
// regardless of which module owns the guard. The previous per-module handlers
// overwrote each other's saved sigaction, so whichever destructor ran last
// left its own handler installed for good -- and a fault outside its module
// jumped into a foreign jmp_buf.
//
// The return point lives in the guard object and is armed per thread, so a
// fault on a thread that never armed its guard is handed back to the previous
// handler and re-raised, never jumped into another thread's context.

#include <csignal>
#include <csetjmp>
#include <mutex>

class CrashGuard {
public:
    CrashGuard() {
        std::lock_guard<std::mutex> lock(Mutex());
        if (Depth()++ == 0) {
            struct sigaction sa = {};
            sa.sa_handler = Handler;
            sigemptyset(&sa.sa_mask);
            sigaction(SIGSEGV, &sa, &PrevSegv());
            sigaction(SIGBUS, &sa, &PrevBus());
        }
    }

    ~CrashGuard() {
        if (Head() == &m_buf) Head() = m_prev;
        std::lock_guard<std::mutex> lock(Mutex());
        if (--Depth() == 0) {
            sigaction(SIGSEGV, &PrevSegv(), nullptr);
            sigaction(SIGBUS, &PrevBus(), nullptr);
        }
    }

    /** Return point: `sigsetjmp(guard.Buf(), 1)` must run before Arm(). */
    sigjmp_buf& Buf() { return m_buf; }

    /** Make the return point reachable. Call right after sigsetjmp. */
    void Arm() {
        m_prev = Head();
        Head() = &m_buf;
    }

private:
    static void Handler(int sig) {
        sigjmp_buf* buf = Head();
        if (buf) {
            siglongjmp(*buf, sig);
        }
        struct sigaction* prev = (sig == SIGBUS) ? &PrevBus() : &PrevSegv();
        struct sigaction restore = *prev;
        sigaction(sig, &restore, nullptr);
        raise(sig);
    }

    static std::mutex& Mutex() { static std::mutex m; return m; }
    static int& Depth() { static int d = 0; return d; }
    static struct sigaction& PrevSegv() { static struct sigaction sa; return sa; }
    static struct sigaction& PrevBus() { static struct sigaction sa; return sa; }
    static sigjmp_buf*& Head() { static thread_local sigjmp_buf* h = nullptr; return h; }

    sigjmp_buf m_buf = {};
    sigjmp_buf* m_prev = nullptr;
};
