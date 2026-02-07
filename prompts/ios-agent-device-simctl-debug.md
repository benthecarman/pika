# iOS agent-device "simctl not found" debug handoff (Pika)

## Goal
Unblock iOS UI automation using `npx agent-device` by fixing the error:

> `error: tool 'simctl' not found`

This currently blocks iOS "click-through" QA from CI-ish scripts and from `just qa`.

## Repo Context
- Repo: `/Users/justin/code/pika`
- Android automation via `agent-device` works.
- iOS builds work when `DEVELOPER_DIR` is set to Xcode in `justfile`.
- Nix devshell is used (`nix develop`), and it sets toolchain env vars that can interfere with Apple tools.

Relevant files:
- `justfile` (iOS build uses `DEVELOPER_DIR="$DEV_DIR" xcodebuild ...`)
- `tools/xcrun` (wrapper that exports `DEVELOPER_DIR` to `/Applications/Xcode-16.4.0.app/...` and then execs `/usr/bin/xcrun`)
- `tools/simctl` (wrapper that directly execs Xcode's `simctl`)
- `README.md` documents `agent-device` usage
- `rust/build.rs` uses `DEVELOPER_DIR` and has fallbacks via `xcode-select -p` and `xcrun --find ...`

## Observed System State (likely root cause)
- `xcode-select -p` points to Command Line Tools:
  - `/Library/Developer/CommandLineTools`
  - This typically does NOT include iOS Simulator tooling; `xcrun simctl ...` fails.
- Xcode is installed at:
  - `/Applications/Xcode-16.4.0.app`
  - `simctl` exists at:
    - `/Applications/Xcode-16.4.0.app/Contents/Developer/usr/bin/simctl`
- In `nix develop`, `DEVELOPER_DIR` can be set to a Nix Apple SDK path (e.g. `/nix/store/...-apple-sdk-14.4`), which also breaks `xcrun simctl`.
- `agent-device` appears to call `xcrun simctl ...` in a way that ignores local PATH wrappers and/or strips `DEVELOPER_DIR`.

## Repro Steps
From repo root:

```sh
nix develop -c sh -lc './tools/agent-device --platform ios devices --json'
```

Expected: JSON devices list

Actual: error that `simctl` is not found (comes from `xcrun simctl list devices -j`).

Useful confirmation checks:

```sh
# What developer dir is active?
xcode-select -p

# Does xcrun work with explicit DEVELOPER_DIR?
DEVELOPER_DIR=/Applications/Xcode-16.4.0.app/Contents/Developer /usr/bin/xcrun simctl list devices -j

# Does wrapper work?
./tools/xcrun simctl list devices -j
```

## Hypothesis
`agent-device` invokes `/usr/bin/xcrun` directly and:
- either does not inherit `DEVELOPER_DIR` (env is sanitized), and/or
- uses `xcode-select` default path (CommandLineTools), which lacks simctl.

So, wrapping `xcrun` on PATH is insufficient if `agent-device` uses an absolute path, and setting `DEVELOPER_DIR` may not work if the process strips it.

One more gotcha: `agent-device` runs a long-lived daemon under `~/.agent-device`. If it was started
previously under a bad environment (missing `DEVELOPER_DIR`), subsequent runs can keep failing until
the daemon is restarted.

## Likely Fix (most reliable)
Switch the global selected developer directory to Xcode so `xcrun` finds `simctl` without any env vars:

```sh
sudo xcode-select -s /Applications/Xcode-16.4.0.app/Contents/Developer
sudo xcodebuild -license accept || true
```

Then:

```sh
xcrun simctl list devices -j
npx --yes agent-device --platform ios devices --json
```

## If That Doesn’t Work: Next Investigations
1. Confirm what `agent-device` actually runs:
   - Run with debug flags if supported (`--verbose` / env var).
   - `npx --yes agent-device --help` and look for logging options.
2. Check whether `agent-device` uses `execa`/`child_process.spawn` with `env: {}` or similar.
3. If `DEVELOPER_DIR` is stripped, see if `agent-device` supports a config to set `DEVELOPER_DIR` or explicit `xcrun` path.
4. Workaround option:
   - Run `agent-device` outside `nix develop` (so it inherits system Xcode env).
5. Worst-case:
   - Add iOS UI smoke tests using native `XCUITest` (which will still require correct `xcode-select`).

## What Success Looks Like
- `./tools/agent-device --platform ios devices --json` returns device list successfully.
- We can record/replay a basic click-through flow against the iOS simulator.

## If `devices` is Empty
If `./tools/simctl list runtimes` is empty, you do not have any iOS Simulator runtimes installed,
so there will be no devices to boot or list. Install a runtime via:

Xcode -> Settings -> Platforms -> iOS Simulator (download)

Then re-run:

```sh
./tools/ios-sim-ensure
./tools/agent-device --platform ios devices --json
```
