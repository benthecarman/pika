# Repro: Public Relays Reject NIP-70 `protected` Events (Blocks MDK Key Packages)

## Summary
MDK key packages are published as kind `443` events and include the NIP-70 `protected` tag. Multiple popular public relays (e.g. Damus, Primal, nos.lol) reject these events with:

`OK false "blocked: event marked as protected"`

They do **not** appear to send a NIP-42 `AUTH` challenge (at least via `nostr-sdk` `Client` notifications), so automatic/explicit AUTH handling never triggers. As a result, apps using modern MDK cannot publish/fetch key packages on these relays, breaking chat/group creation flows that depend on kind `443`.

## Minimal Repro (Rust, in this repo)

### 1) Build the probe
```bash
cd /Users/justin/code/pika
nix develop -c cargo build -p pika_core --bin relay_probe
```

### 2) Publish a *protected* kind 443 (expected: rejected)
```bash
cd /Users/justin/code/pika
target/debug/relay_probe wss://relay.damus.io --kind 443
target/debug/relay_probe wss://relay.primal.net --kind 443
target/debug/relay_probe wss://nos.lol --kind 443
```

Expected output pattern:
```text
send_event_to(...): success=0 failed=1
failed: { "wss://...": "blocked: event marked as protected" }
msg from wss://...: Ok { ..., status: false, message: "blocked: event marked as protected" }
```

### 3) Publish an *unprotected* kind 443 (expected: accepted)
```bash
cd /Users/justin/code/pika
target/debug/relay_probe wss://relay.damus.io --kind 443 --unprotected
target/debug/relay_probe wss://relay.primal.net --kind 443 --unprotected
```

Expected output pattern:
```text
send_event_to(...): success=1 failed=0
```

## Why This Matters
- Modern MDK publishes MLS key packages as kind `443` **with** NIP-70 `protected`.
- If major relays reject protected events (without NIP-42 auth flow), then default relay choices (Damus/Primal/nos.lol/etc.) will not work for MLS bootstrap.
- Practical outcomes:
  - “Create chat” / “Start group” stalls because peer key package never becomes visible.
  - Public-relay E2E tests fail unless you use a relay that accepts protected events.

## Questions For Marmot/MDK
1. Is there an intended compatibility mode to publish MLS key packages **without** `protected`?
2. If not, is the intended design to use dedicated “key package relays” (e.g. via kind `10051` / `MlsKeyPackageRelays`) that explicitly accept protected events?
3. Are there known public relays that accept NIP-70 `protected` for kind `443` without requiring special allowlists?

