set shell := ["bash", "-lc"]

default:
  @just --list

test:
  cargo test -p pika_core

fmt:
  cargo fmt --all --check

clippy:
  cargo clippy -p pika_core --all-targets -- -D warnings

qa: fmt clippy test android-assemble ios-build-sim
  @echo "QA complete"

# Manual-only nondeterministic smoke test using public relays.
# Optional:
#   PIKA_E2E_RELAYS="wss://relay.damus.io,wss://relay.primal.net" just e2e-public
#   PIKA_E2E_KP_RELAYS="wss://nostr-pub.wellorder.net,wss://nostr-01.yakihonne.com,..." just e2e-public
e2e-public:
  PIKA_E2E_PUBLIC=1 cargo test -p pika_core --test e2e_public_relays -- --ignored --nocapture

rust-build-host:
  cargo build -p pika_core --release

gen-kotlin: rust-build-host
  mkdir -p android/app/src/main/java/com/pika/app/rust
  # Resolve the host cdylib extension (dylib on macOS, so on Linux).
  LIB=$(ls -1 target/release/libpika_core.dylib target/release/libpika_core.so target/release/libpika_core.dll 2>/dev/null | head -n 1); \
  if [ -z "$LIB" ]; then echo "Missing built library: target/release/libpika_core.*"; exit 1; fi; \
  cargo run -q -p uniffi-bindgen -- generate \
    --library "$LIB" \
    --language kotlin \
    --out-dir android/app/src/main/java \
    --no-format \
    --config rust/uniffi.toml

android-rust:
  mkdir -p android/app/src/main/jniLibs
  cargo ndk -o android/app/src/main/jniLibs \
    -t arm64-v8a -t armeabi-v7a -t x86_64 \
    build -p pika_core --release

android-local-properties:
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"; \
  if [ -z "$SDK" ]; then echo "ANDROID_HOME/ANDROID_SDK_ROOT not set (run inside nix develop)"; exit 1; fi; \
  printf "sdk.dir=%s\n" "$SDK" > android/local.properties

android-assemble: gen-kotlin android-rust android-local-properties
  cd android && ./gradlew :app:assembleDebug

android-install: gen-kotlin android-rust android-local-properties
  cd android && ./gradlew :app:installDebug

android-ui-test: gen-kotlin android-rust android-local-properties
  # Requires a running emulator/device (instrumentation tests).
  cd android && ./gradlew :app:connectedDebugAndroidTest

# iOS (Xcode build happens outside Nix; Nix helps with Rust + xcodegen).
ios-gen-swift: rust-build-host
  mkdir -p ios/Bindings
  cargo run -q -p uniffi-bindgen -- generate \
    --library target/release/libpika_core.dylib \
    --language swift \
    --out-dir ios/Bindings \
    --config rust/uniffi.toml

ios-rust:
  set -euo pipefail; \
  DEV_DIR=$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | sort | tail -n 1); \
  if [ -z "$DEV_DIR" ]; then echo "Xcode not found under /Applications (needed for iOS SDK)"; exit 1; fi; \
  env -u LIBRARY_PATH DEVELOPER_DIR="$DEV_DIR" RUSTFLAGS="-C link-arg=-miphoneos-version-min=17.0" cargo build -p pika_core --release --target aarch64-apple-ios; \
  env -u LIBRARY_PATH DEVELOPER_DIR="$DEV_DIR" RUSTFLAGS="-C link-arg=-mios-simulator-version-min=17.0" cargo build -p pika_core --release --target aarch64-apple-ios-sim; \
  env -u LIBRARY_PATH DEVELOPER_DIR="$DEV_DIR" RUSTFLAGS="-C link-arg=-mios-simulator-version-min=17.0" cargo build -p pika_core --release --target x86_64-apple-ios

ios-xcframework: ios-gen-swift ios-rust
  rm -rf ios/Frameworks/PikaCore.xcframework ios/.build
  mkdir -p ios/.build/headers ios/Frameworks
  cp ios/Bindings/pika_coreFFI.h ios/.build/headers/pika_coreFFI.h
  cp ios/Bindings/pika_coreFFI.modulemap ios/.build/headers/module.modulemap
  DEV_DIR=$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | sort | tail -n 1); \
  if [ -z "$DEV_DIR" ]; then echo "Xcode not found under /Applications"; exit 1; fi; \
  DEVELOPER_DIR="$DEV_DIR" xcrun lipo -create \
    target/aarch64-apple-ios-sim/release/libpika_core.a \
    target/x86_64-apple-ios/release/libpika_core.a \
    -output ios/.build/libpika_core_sim.a; \
  DEVELOPER_DIR="$DEV_DIR" xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libpika_core.a -headers ios/.build/headers \
    -library ios/.build/libpika_core_sim.a -headers ios/.build/headers \
    -output ios/Frameworks/PikaCore.xcframework

ios-xcodeproj:
  cd ios && xcodegen generate

ios-build-sim: ios-xcframework ios-xcodeproj
  DEV_DIR=$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | sort | tail -n 1); \
  if [ -z "$DEV_DIR" ]; then echo "Xcode not found under /Applications"; exit 1; fi; \
  env -u LD -u CC -u CXX DEVELOPER_DIR="$DEV_DIR" xcodebuild -project ios/Pika.xcodeproj -target Pika -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO

# Requires at least one installed iOS Simulator runtime + device.
# If `./tools/simctl list runtimes` is empty, install a simulator runtime via:
# Xcode -> Settings -> Platforms -> iOS Simulator (download), then retry.
IOS_DESTINATION := "platform=iOS Simulator,name=iPhone 15"
ios-ui-test: ios-xcframework ios-xcodeproj
  DEV_DIR=$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | sort | tail -n 1); \
  if [ -z "$DEV_DIR" ]; then echo "Xcode not found under /Applications"; exit 1; fi; \
  if [ -z "$(./tools/simctl list runtimes | tail -n +2 | tr -d '[:space:]')" ]; then \
    echo "No iOS Simulator runtimes installed (simctl list runtimes is empty)."; \
    echo "Install one via: Xcode -> Settings -> Platforms -> iOS Simulator (download)"; \
    exit 1; \
  fi; \
  env -u LD -u CC -u CXX DEVELOPER_DIR="$DEV_DIR" xcodebuild -project ios/Pika.xcodeproj -scheme Pika -destination "{{IOS_DESTINATION}}" test CODE_SIGNING_ALLOWED=NO

# Optional: device automation (npx). Not required for building.
device:
  ./tools/agent-device --help

android-manual-qa:
  @echo "Manual QA prompt: prompts/android-agent-device-manual-qa.md"
  @echo "Tip: run `npx --yes agent-device --platform android open com.pika.app` then follow the prompt."

ios-manual-qa:
  @echo "Manual QA prompt: prompts/ios-agent-device-manual-qa.md"
  @echo "Tip: run `./tools/agent-device --platform ios open com.pika.app` then follow the prompt."

run-android:
  ./tools/run-android

run-ios:
  ./tools/run-ios

doctor-ios:
  ./tools/ios-runtime-doctor
