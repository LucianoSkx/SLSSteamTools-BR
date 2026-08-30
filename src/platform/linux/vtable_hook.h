#pragma once

#include <cstdint>
#include <cstddef>

namespace VtableHook
{
    // Resolved vtable state
    struct VtableInfo
    {
        void** vtable;              // Pointer to the function pointer array (past offset-to-top + typeinfo)
        void*  origSlot5;           // BYieldingSendMessageAndGetReply
        void*  origSlot7;           // NotificationDirect
        void*  origSlot8;           // SyncSend2
    };

    struct CloudEnabledHookInfo
    {
        void** vtable;
        void*  origSlot;
        size_t slotIndex;
    };

    // Find steamclient.so in memory via /proc/self/maps.
    // Returns base address, sets size. Returns 0 on failure.
    uintptr_t FindSteamclient(size_t& outSize);

    // Re-snapshot the mapping ranges for the module bounds resolved by the last
    // FindSteamclient() call. Returns false if no module is resolved yet.
    bool RefreshRanges();

    // Locate CClientUnifiedServiceTransport vtable via RTTI scan.
    // steamBase/steamSize from FindSteamclient().
    // Returns pointer to function pointer array (slot 0), or nullptr.
    void** FindTransportVtable(uintptr_t steamBase, size_t steamSize);

    // Resolve the transport vtable, re-running FindSteamclient() between
    // attempts. Both the module bounds and the fragmentation of its mapping
    // change while the client starts, so a single pass can miss .data.rel.ro.
    // Cancels early when the process is exiting. Sets outBase/outSize to the
    // last resolved module bounds even when the vtable is not found, so callers
    // can tell "steamclient absent" from "vtable unresolved".
    void** ResolveTransportVtable(uintptr_t& outBase, size_t& outSize,
                                  int maxAttempts = 12, int retryDelayMs = 250);

    // Locate CUserRemoteStorage vtable via RTTI scan.
    void** FindRemoteStorageVtable(uintptr_t steamBase, size_t steamSize);

    // Locate the primary vtable for a type by its Itanium-mangled RTTI name
    // (e.g. "22CMsgClientGetUserStatsE"). Returns slot-0 pointer or nullptr.
    void** FindVtableByRTTIName(const char* mangledName,
                                uintptr_t steamBase, size_t steamSize);

    // Find a global instance whose first word holds `vtablePtr` by scanning
    // writable ranges. Returns nullptr if none found.
    void* FindGlobalWithVtable(void* vtablePtr,
                               uintptr_t steamBase, size_t steamSize);

    // Swap vtable slots 5, 7, 8 with our hooks. Saves originals into `info`.
    bool InstallHooks(void** vtable, VtableInfo& info);

    // Hook slot 24 (IsCloudEnabledForApp) on CUserRemoteStorage.
    bool InstallCloudEnabledHook(void** vtable, CloudEnabledHookInfo& info);

    // Restore original vtable slots.
    void RemoveHooks(const VtableInfo& info);
    void RemoveCloudEnabledHook(const CloudEnabledHookInfo& info);
}
