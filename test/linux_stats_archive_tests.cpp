#include "stats_store.h"
#include "metadata_sync.h"
#include <filesystem>
#include <fstream>
#include <cstdio>
#include <cstdlib>

int main() {
    namespace fs = std::filesystem;
    char pattern[] = "/tmp/cr_stats_archive_XXXXXX";
    const char* dir = mkdtemp(pattern);
    if (!dir) return 2;
    const fs::path root(dir);
    int failures = 0;
    auto check = [&](bool ok, const char* label) {
        std::printf("%s: %s\n", ok ? "ok" : "FAIL", label);
        if (!ok) ++failures;
    };
    fs::create_directories(root / "storage/77/0/Playtime");
    std::ofstream(root / "storage/77/0/Playtime/12345.bin")
        << R"({"Playtime":"40","LastPlayed":"1700000000","Playtime2wks":"20"})";
    StatsStore::SetAccountIdProvider([] { return 77; });
    StatsStore::SetNamespacePredicate([](uint32_t) { return true; });
    StatsStore::SetEligibilityPredicate([](uint32_t) { return false; });
    StatsStore::Init(root.string(), (root / "steam").string());
    StatsStore::SeedApps({12345});
    check(fs::exists(root / "stats/77/12345.json"),
          "unknown license does not strand the legacy backup during migration");
    check(StatsStore::GetTrackedApps().empty(), "archived playtime is not delivered to an official game");
    StatsStore::ResetForTesting();
    StatsStore::SetEligibilityPredicate([](uint32_t) { return true; });
    StatsStore::SeedApps({12345});
    check(StatsStore::Snapshot(12345).playtime.minutesForever == 40,
          "legacy history survives process-equivalent cache reset and later eligibility");
    StatsStore::SetEligibilityPredicate([](uint32_t) { return false; });
    check(StatsStore::GetTrackedApps().empty(), "losing eligibility stops delivery without deleting history");
    check(fs::exists(root / "stats/77/12345.json"), "private backup stays on disk");
    StatsStore::ResetForTesting();
    fs::remove_all(root);
    return failures ? 1 : 0;
}
