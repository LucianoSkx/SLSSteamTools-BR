#pragma once

#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <unordered_set>

namespace LinuxLateDiscovery {

class Queue {
public:
    bool Enqueue(uint32_t appId) noexcept {
        if (appId == 0) return false;
        try {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (m_stopped) return false;
            const auto [seenIt, inserted] = m_seen.insert(appId);
            if (!inserted) return false;
            try {
                m_pending.push_back(appId);
            } catch (...) {
                m_seen.erase(seenIt);
                return false;
            }
        } catch (...) {
            return false;
        }
        m_cv.notify_one();
        return true;
    }

    bool TryPop(uint32_t& appId) noexcept {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_stopped || m_pending.empty()) return false;
        appId = m_pending.front();
        m_pending.pop_front();
        return true;
    }

    bool WaitPop(uint32_t& appId) noexcept {
        std::unique_lock<std::mutex> lock(m_mutex);
        m_cv.wait(lock, [this] { return m_stopped || !m_pending.empty(); });
        if (m_stopped) return false;
        appId = m_pending.front();
        m_pending.pop_front();
        return true;
    }

    void Stop() noexcept {
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_stopped = true;
            m_pending.clear();
        }
        m_cv.notify_all();
    }

    std::size_t Pending() const noexcept {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_pending.size();
    }

private:
    mutable std::mutex m_mutex;
    std::condition_variable m_cv;
    std::deque<uint32_t> m_pending;
    std::unordered_set<uint32_t> m_seen;
    bool m_stopped = false;
};

template <typename Handler, typename OnFailure>
void Drain(Queue& queue, Handler&& handler, OnFailure&& onFailure) noexcept {
    uint32_t appId = 0;
    while (queue.WaitPop(appId)) {
        try {
            handler(appId);
        } catch (...) {
            try {
                onFailure(appId);
            } catch (...) {
            }
        }
    }
}

} // namespace LinuxLateDiscovery
