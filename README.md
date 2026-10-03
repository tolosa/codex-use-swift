# Codex Usage

A small native macOS 27 app for your current Codex account limits. Built with SwiftUI, Observation, Liquid Glass cards and controls, and a menu-bar panel.

- Remaining capacity for each reported usage window, with reset countdowns and local reset times.
- Analog reset clock beside the title, with five numbered five-hour sectors and no seconds hand. Reset 1 is the projected reset nearest today's local noon; the long hand circles once per five-hour window. Five sectors form a 25-hour dial, with numbering anchored again each day. The schedule follows the reported five-hour reset timestamp.
- Account plan, credit balance when provided, and separate limit buckets when returned by Codex.
- Automatic refresh every 60 seconds, plus manual refresh with **⌘R**.
- Menu-bar percentage reflects the primary Codex window's remaining capacity.
- Connection settings support automatic executable discovery or a custom Codex executable.
- Failed refreshes preserve the last successful reading with an explicit stale-data notice.

To change the number of small clock ticks between reset markers, edit `minuteTicksPerReset` in `codex-usage-swift/ResetClock.swift` (defaults to 5). Without a reported five-hour reset time, the clock shows its face with a dash in place of the hands.

## Run

Open `codex-usage-swift.xcodeproj` in **Xcode 27**, select the `codex-usage-swift` scheme and **My Mac**, and run. Requires **macOS 27 or later** and a locally installed Codex CLI signed in with a ChatGPT account. If needed, run `codex login` in Terminal first.

Automatic discovery checks Homebrew, `~/.local/bin`, `~/.cargo/bin`, the Codex app bundle, and inherited PATH entries. Use **Settings → Executable path** for another installation, including a CLI installed through a version manager. The app inherits `CODEX_HOME` when supplied by its launch environment; otherwise Codex uses its normal default home.

Build from Terminal:

```sh
xcodebuild -project codex-usage-swift.xcodeproj \
  -scheme codex-usage-swift -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/codex-usage-build \
  CODE_SIGNING_ALLOWED=NO build
open /tmp/codex-usage-build/Build/Products/Debug/codex-usage-swift.app
```

## Data and credentials

The app launches `codex app-server --listen stdio://`, performs the initialization handshake, then calls only `account/read` and `account/rateLimits/read`. Each refresh closes its helper process. It never starts an agent turn. Codex handles existing authentication; the app doesn't read or store tokens, auth files, conversation history, or usage responses. Only a custom executable path is saved in UserDefaults.

App Sandbox is disabled because the app needs to execute your installed CLI and let that process access its existing login. This is a local developer application, not an App Store build. The dashboard displays ChatGPT subscription limits, not API billing or a token-cost estimate. API-key and Bedrock accounts receive an explanatory state.

The [Codex app-server documentation](https://learn.chatgpt.com/docs/app-server) describes the account endpoints. The UI uses Apple's [Liquid Glass APIs](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), including `GlassEffectContainer`, `glassEffect`, and glass button styles.

## Verification

```sh
./Tests/run-checks.sh
# Also verify the actual locally signed-in account (requires network access):
./Tests/run-checks.sh --live
```

Checks cover decoding, bucket ordering, percentage bounds, missing windows/reset times, signed-out accounts, missing executables, and the JSONL handshake with fragmented responses and unsolicited notifications. Live mode exercises the same Swift client as the app and omits account details from output.
