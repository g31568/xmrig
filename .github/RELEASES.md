# Automated releases

`upstream-release.yml` checks `xmrig/xmrig`'s `master` branch daily at
03:17 UTC (11:17 Taipei), or when manually run from the Actions tab. It also
runs when this workflow, its helpers, or donation settings change on `master`.

The sync job merges upstream into this fork's default branch, reapplies zero
default/minimum donation levels and zero bundled config defaults, then pushes
the result. Merge conflicts and protected-branch rejections stop the run
without overwriting fork changes. Updating upstream workflow files may require
a token with workflow write permission beyond the built-in `GITHUB_TOKEN`.

All builds check out the same patched commit. Windows uses UCRT64 GCC and
upstream's prebuilt static dependencies. Linux and macOS build dependencies
using upstream's scripts. Windows includes the upstream MSR driver and example
scripts; every archive includes `config.json` and `LICENSE`.

| Runner | Archive | Target |
| --- | --- | --- |
| `windows-latest` | `xmrig-windows-x86-64-v3.zip` | `-march=x86-64-v3` |
| `ubuntu-latest` | `xmrig-linux-x86-64-v3.tar.gz` | `-march=x86-64-v3`, static |
| `macos-latest` | `xmrig-macos-arm64.tar.gz` | ARM64, static third-party libraries |

The x86 packages require an x86-64-v3 CPU. Linux's static libc build still
requires a compatible kernel. macOS requires the runner's deployment target
or newer; this workflow does not sign or notarize the binary.

A release is named `build-<upstream SHA prefix>-<patched SHA prefix>`. Completed
releases are skipped when the source is unchanged. Failed builds and incomplete
draft releases are retried on the next run. Publication waits for all three
builds, includes `SHA256SUMS`, and exposes the exact patched source via GitHub's
source archives.

To activate, push these files to the default branch and enable Actions on the
fork. Allow the workflow to write repository contents and push to the default
branch. Use **Actions → Sync upstream and release → Run workflow** for the
first build. GitHub may disable scheduled workflows in inactive repositories;
re-enable them in Actions when needed. If the default branch is renamed, update
the workflow's `push.branches` filter.
