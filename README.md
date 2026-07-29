# Comunicator

Native **macOS** shell for web messaging apps — WhatsApp Web, Google Messages, Slack, Messenger, Telegram, and custom URLs — each in an isolated tab with desktop notifications.

Open source under the [MIT License](LICENSE). You may use, modify, and redistribute with credit: keep the copyright notice.

**Copyright © 2026 Jono Clark**

## Features

- Multi-tab WebKit shell with per-account session isolation
- Desktop notifications + dock badge (title unread heuristics)
- Rename tabs/accounts, mute per tab, clear/delete sessions
- Keyboard tab switching (`⌘1`–`⌘9`)
- Downloads via Save panel; camera/mic permissions for in-page calls
- Works without the paid Apple Developer Program for local/internal builds (Gatekeeper caveat below)

## Requirements

- macOS 14+
- [Xcode](https://developer.apple.com/xcode/) 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — used to generate the Xcode project from `project.yml`

## Build (development)

```bash
brew install xcodegen   # if needed
xcodegen generate
open Comunicator.xcodeproj
```

Or:

```bash
xcodegen generate
xcodebuild -scheme Comunicator -configuration Debug build
```

## Release build (for sharing)

Produces a Release app in [`releases/`](releases/):

```bash
./scripts/build-release.sh
```

Output: `releases/Comunicator.app` (also zipped as `releases/Comunicator.zip`).

### Installing on other Macs (no Apple Developer Program)

Notarized Developer ID builds are not available without a paid Apple developer membership. For trusted/internal users:

1. Unzip `Comunicator.zip`
2. **Right-click** `Comunicator.app` → **Open** → **Open**
3. If blocked: System Settings → Privacy & Security → **Open Anyway**  
   Or: `xattr -cr /path/to/Comunicator.app`

## Usage

1. Open a service from the sidebar (or **Custom URL…**).
2. **⋯ → Add Account…** for another login of the same service (isolated cookies).
3. Rename via double-click tab, context menu, or **Session → Rename Tab…** (`⇧⌘R`).
4. Mute notifications per tab from the toolbar or Session menu.

## Project layout

```
Comunicator/           # App sources
project.yml            # XcodeGen project definition
scripts/build-release.sh
releases/                # Release .app / .zip output (binaries not committed)
LICENSE
README.md
```

## Credits

- Created by **Jono Clark**
- Built with SwiftUI + WebKit
- Messaging UIs belong to their respective providers (WhatsApp, Google, Slack, Meta, Telegram, etc.). This project only embeds their public web clients.

## Contributing

PRs and forks are welcome. Please:

1. Keep the MIT license and copyright notice
2. Credit **Jono Clark** (and note your changes) in your README or About text when redistributing a modified build

## Disclaimer

Unofficial third-party client shell. Not affiliated with Meta, Google, Slack, Telegram, or Apple. Use at your own risk and comply with each service’s terms of use.
