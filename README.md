# cloudredirect-moon

A branch of [CloudRedirect](https://github.com/Selectively11/CloudRedirect)
that redirects Steam Cloud reads/writes to the user's own storage. This branch
adds cross-distro attach fixes, legacy save-layout healing, and worker-thread
crash containment on the Linux 32-bit hook.

The result is a 32-bit `cloud_redirect.so`, loaded into Steam via `LD_PRELOAD`.

## Linux achievement scope

Namespace membership alone is not a license decision. CloudRedirect stats and
playtime delivery require confirmation from the matching SLSsteam build through
`slsteam_local_stats_epoch_v1`. Real licenses, unknown state and queries for
other users pass through to Steam. SLSsteam owns achievement-schema fetching,
matching upstream CloudRedirect's Linux architecture. Install both updated
libraries together; without the bridge, local stats handling is disabled safely.

Private backups and legacy migration remain intact; they are not applied to
official games or replayed to a Steam profile. Cloud save routing is unchanged.
After switching accounts within the same Steam process, restart Steam fully to
reinitialize the account-scoped store; until then stats remain on the official
path. This deliberately avoids mixing two accounts' archived progress.

Run `ctest --test-dir build --output-on-failure` after the portable build for the
Linux scope, missing-bridge, migration and existing runtime regressions.

## Credits

Upstream:

- [Selectively11](https://github.com/Selectively11) and contributors —
  the CloudRedirect hook this branch builds on.

## Support

Open an issue: https://github.com/swwayps/cloudredirect-moon/issues
