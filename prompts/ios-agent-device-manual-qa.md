# iOS Manual QA (agent-device) - Pika

Goal: manually verify routing + basic chat flows on iOS using the same Rust-owned state/router architecture as Android.

## Prereqs
- Full Xcode installed under `/Applications`.
- At least one iOS Simulator runtime installed.
  - Check: `./tools/simctl list runtimes`
  - If empty: Xcode -> Settings -> Platforms -> download an iOS Simulator runtime.

## Launch
```sh
nix develop -c sh -lc './tools/agent-device --platform ios open com.pika.app --verbose'
```

If you see `DEVICE_NOT_FOUND`, you have no simulator runtimes/devices installed yet (see Prereqs).

## Flow To Test (V1/V2 spirit)
1. Login screen:
   - Tap `Create Account`.
2. Chat list:
   - Verify title is `Chats`.
   - Open `My npub`, verify alert shows an `npub1...`.
   - Tap `New Chat`.
3. New chat:
   - Paste/type your own `npub1...` (note-to-self).
   - Tap `Start Chat`.
4. Chat:
   - Type `hi` and tap `Send`.
   - Verify your message appears with a delivery indicator (pending/sent/failed is fine; presence is key).
5. Back:
   - Navigate back to `Chats` and `Logout`.
6. Relaunch:
   - Relaunch the app and confirm session restore works (you should land on `Chats` without re-login).

## Debug Tips
- Use `snapshot` to inspect accessibility and element ids:
  - `./tools/agent-device --platform ios snapshot -i`
- If routing seems off, grab a screenshot:
  - `./tools/agent-device --platform ios screenshot /tmp/pika_ios.png`

