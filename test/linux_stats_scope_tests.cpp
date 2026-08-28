#include "stats_hooks.h"
#include "stats_handlers.h"
#include "metadata_sync.h"
#include "cloud_intercept.h"
#include "protobuf.h"
#include "stats_eligibility.h"
#include <cstdio>

static uint64_t policy = 0;
static bool changeDuringRead = false;
static uint32_t account = 39734273;
#ifdef STATS_TEST_WITH_BRIDGE
extern "C" uint64_t slsteam_local_stats_epoch_v1(uint32_t app, uint32_t id, uint32_t) noexcept {
    return id == 39734273 && app == 12345 ? policy : 0;
}
#endif

namespace CloudIntercept {
bool IsNamespaceApp(uint32_t id) { return id == 12345; }
uint32_t GetAccountId() { return account; }
}
namespace StatsHandlers {
CloudIntercept::RpcResult HandleGetUserStats(uint32_t, const std::vector<PB::Field>&) {
    if (changeDuringRead) policy = 0;
    PB::Writer body; body.WriteVarint(2, 42);
    return CloudIntercept::RpcResult(std::move(body));
}
CloudIntercept::RpcResult HandleGetLastPlayedTimes(const std::vector<PB::Field>&) {
    return CloudIntercept::RpcResult(PB::Writer{});
}
}
int main() {
    PB::Writer body;
    body.WriteVarint(1, 76561198000000001ULL);
    body.WriteVarint(2, 12345);
    int parses = 0, flags[4] = {8, 9, 10, 11};
    StatsHooks::SetProtobufHelpers(
        [&](void*) { return body.Data(); },
        [&](void*, const uint8_t*, size_t) { ++parses; return true; });
    MetadataSync::syncAchievements = true;
    bool handled = StatsHooks::TryHandleGetUserStats(StatsHandlers::RPC_GET_USER_STATS,
                                                   &body, &body, flags);
    bool ok = !handled && parses == 0 && flags[2] == 10 && flags[3] == 11;
    std::printf("%s: unknown license preserves official response and transport flags\n",
                ok ? "ok" : "FAIL");
    int failures = ok ? 0 : 1;
    auto check = [&](bool value, const char* label) {
        std::printf("%s: %s\n", value ? "ok" : "FAIL", label);
        if (!value) ++failures;
    };
    auto call = [&]() { return StatsHooks::TryHandleGetUserStats(
        StatsHandlers::RPC_GET_USER_STATS, &body, &body, flags); };
#ifdef STATS_TEST_WITH_BRIDGE
    policy = 9;
    check(call() && parses == 1 && flags[2] == 1, "confirmed local license still uses local stats");
    body = {}; body.WriteVarint(1, 76561198000000002ULL); body.WriteVarint(2, 12345);
    check(!call() && parses == 1, "another user's modern query passes through");
    body = {}; body.WriteVarint(1, 76561198000000001ULL); body.WriteVarint(2, 12345);
    changeDuringRead = true;
    check(!call() && parses == 1, "license change during read does not publish stale response");
    changeDuringRead = false; policy = 9;
    MetadataSync::syncAchievements = false;
    check(!call(), "disabled achievements pass through"); MetadataSync::syncAchievements = true;
    account = 0; check(!call(), "unknown account passes through"); account = 39734273;
    PB::Writer legacy; legacy.WriteFixed64(1, 12345); legacy.WriteFixed64(4, 76561198000000001ULL);
    auto fields = PB::Parse(legacy.Data().data(), legacy.Size()); uint32_t app = 0;
    check(StatsEligibility::RequestEpoch(fields, true, app) == 9 && app == 12345,
          "legacy self request requires the same license proof");
    legacy = {}; legacy.WriteFixed64(1, 12345); legacy.WriteFixed64(4, 76561198000000002ULL);
    fields = PB::Parse(legacy.Data().data(), legacy.Size());
    check(!StatsEligibility::RequestEpoch(fields, true, app), "legacy friend request passes through");
    legacy = {}; legacy.WriteFixed64(1, (1ULL << 32) | 12345);
    fields = PB::Parse(legacy.Data().data(), legacy.Size());
    check(!StatsEligibility::RequestEpoch(fields, true, app), "non-app game ID cannot alias a managed app");
    PB::Writer times, game; game.WriteVarint(1, 12345); game.WriteVarint(4, 20);
    times.WriteSubmessage(1, game);
    check(!StatsEligibility::FilterLastPlayed(times.Data()).empty(), "local playtime remains available");
    policy = 0;
    check(StatsEligibility::FilterLastPlayed(times.Data()).empty(), "queued playtime is removed after license changes");
#else
    check(!StatsEligibility::Epoch(12345, true), "missing/old SLS bridge fails closed");
#endif
    return failures ? 1 : 0;
}
