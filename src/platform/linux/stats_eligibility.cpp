#include "stats_eligibility.h"
#include "cloud_intercept.h"
#include <dlfcn.h>

// dlsym cannot normally see LD_AUDIT objects. SLSsteam redirects this versioned
// fallback via la_symbind32. Old/missing SLSsteam => official passthrough.
extern "C" __attribute__((weak, visibility("default")))
uint64_t slsteam_local_stats_epoch_v1(uint32_t, uint32_t, uint32_t) noexcept { return 0; }

namespace StatsEligibility {
uint64_t Epoch(uint32_t appId, bool refresh) {
    if (!appId || !CloudIntercept::IsNamespaceApp(appId)) return 0;
    const auto account = CloudIntercept::GetAccountId();
    if (!account) return 0;
    using Query = uint64_t (*)(uint32_t, uint32_t, uint32_t);
    static const auto query = reinterpret_cast<Query>(
        dlsym(RTLD_DEFAULT, "slsteam_local_stats_epoch_v1"));
    return query ? query(appId, account, refresh ? 1 : 0) : 0;
}
bool IsLocalApp(uint32_t appId) { return Epoch(appId) != 0; }

uint64_t RequestEpoch(const std::vector<PB::Field>& fields, bool legacy, uint32_t& appId) {
    appId = 0;
    uint64_t target = 0;
    bool gotApp = false, gotTarget = false;
    for (const auto& field : fields) {
        if (field.fieldNum == (legacy ? 1u : 2u)) {
            if (gotApp || field.wireType != (legacy ? PB::Fixed64 : PB::Varint) ||
                !field.varintVal || field.varintVal > UINT32_MAX) return 0;
            appId = static_cast<uint32_t>(field.varintVal);
            gotApp = true;
        } else if (field.fieldNum == (legacy ? 4u : 1u)) {
            if (gotTarget || field.wireType != (legacy ? PB::Fixed64 : PB::Varint)) return 0;
            target = field.varintVal;
            gotTarget = true;
        }
    }
    const auto account = CloudIntercept::GetAccountId();
    if (!gotApp || !account || (target && target != (0x0110000100000000ULL | account))) return 0;
    return Epoch(appId, true);
}

std::vector<uint8_t> FilterLastPlayed(const std::vector<uint8_t>& body) {
    PB::Writer out;
    for (const auto& field : PB::Parse(body.data(), body.size())) {
        if (field.fieldNum != 1 || field.wireType != PB::LengthDelimited) continue;
        const auto fields = PB::Parse(field.data, field.dataLen);
        const auto* app = PB::FindField(fields, 1);
        if (app && app->wireType == PB::Varint && app->varintVal <= UINT32_MAX &&
            IsLocalApp(static_cast<uint32_t>(app->varintVal)))
            out.WriteBytes(1, field.data, field.dataLen);
    }
    return out.Data();
}
}
