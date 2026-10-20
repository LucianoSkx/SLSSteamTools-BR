#pragma once
#include "protobuf.h"

namespace StatsEligibility {
// 0 = official passthrough. Nonzero = account/license generation. Only Steam
// hook threads may refresh; background workers only consult cached evidence.
uint64_t Epoch(uint32_t appId, bool refresh = false);
uint64_t RequestEpoch(const std::vector<PB::Field>& fields, bool legacy, uint32_t& appId);
bool IsLocalApp(uint32_t appId);
std::vector<uint8_t> FilterLastPlayed(const std::vector<uint8_t>& body);
}
