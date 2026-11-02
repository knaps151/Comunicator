# Comunicator Help

User guide for **Comunicator 1.0.2** — a native macOS shell for web messaging apps.

**In the app:** **Help → Comunicator Help** (or `⌘?`).

Site: [knaps151.github.io/Comunicator](https://knaps151.github.io/Comunicator/) · [Styled help page](https://knaps151.github.io/Comunicator/help.html)

## What it is

Comunicator wraps public web clients (WhatsApp Web, Google Messages, Slack, Messenger, Telegram, or a custom HTTPS URL) in a multi-tab macOS window. Each account gets its own isolated WebKit session (cookies and site data), plus desktop notifications and a dock badge when unread counts appear in the page title.

It is an unofficial third-party shell — not affiliated with Meta, Google, Slack, Telegram, or Apple.

## Requirements

- macOS 14 or later
- Apple Silicon (arm64) for the published Release zip

## Install

1. Download [`Comunicator.zip`](https://github.com/knaps151/Comunicator/releases/latest/download/Comunicator.zip) from [GitHub Releases](https://github.com/knaps151/Comunicator/releases).
2. Unzip `Comunicator.app`.
3. On first open, macOS may show **“Comunicator” Not Opened** (Apple could not verify…). Click **Done** (not Move to Bin).
4. Open **System Settings → Privacy & Security**, scroll to the security message about Comunicator, and click **Open Anyway**. Confirm again if asked.
5. Or **right-click** the app → **Open** → **Open** (works on some macOS versions).

Builds are ad-hoc signed and not notarized (no paid Apple Developer Program). Only install builds you trust.

Trusted builds only — clear quarantine flags, then open:

```bash
xattr -cr /path/to/Comunicator.app
open /path/to/Comunicator.app
```

## Getting started

1. Pick a service in the sidebar (WhatsApp, Google Messages, Slack, Messenger, Telegram).
2. Sign in inside the embedded browser as you would on the web.
3. Use **Custom URL…** for another HTTPS messaging site.
4. Open another account of the same service with **⋯ → Add Account…** — each account stays isolated.

## Accounts and sessions

| Action | What it does |
|--------|----------------|
| **Add Account** | Creates a new profile with its own cookies/storage for that service |
| **Rename** | Changes the display name (double-click tab, context menu, or **Session → Rename Tab…**) |
| **Clear Session Cookies…** | Signs you out in Comunicator by wiping that profile’s site data |
| **Delete Account** | Removes the profile, open tab, and stored login data (cannot be undone) |

## Tabs and shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘1` … `⌘9` | Switch to tab 1–9 |
| `⌘R` | Reload active tab |
| `⇧⌘R` | Rename active tab |
| `⇧⌘M` | Mute / unmute notifications for the active tab |

Also available from the toolbar: **Reload** and **Mute**.

Open tabs stay live in the background so unread badges can still update. Opening many tabs uses more memory — Comunicator shows a warning when a lot are open.

## Notifications

- Desktop banners appear when the page title suggests unread messages (patterns like `(3)`, `3 ·`, or `[3]`).
- The dock badge aggregates unmuted tabs.
- Mute a tab from the toolbar or **Session** menu if you only want that account quiet.
- Clicking a notification focuses that tab.

**Note:** Unread detection is title-based. Services that don’t put a count in the window title may not badge or notify reliably.

## Custom URLs

- Must be **HTTPS**.
- Camera/mic and some SSO flows may be limited for unknown hosts; built-in services include `allowedHosts` for common login domains.

## Camera, microphone, and files

- In-page calls can use camera and mic after macOS permission prompts for Comunicator.
- Permissions are only granted for the main frame on allowed origins for that service.
- Downloads and file uploads use the standard macOS save/open panels.

## Troubleshooting

| Problem | Try this |
|---------|----------|
| App won’t open | Right-click → Open, or Privacy & Security → Open Anyway |
| Still blocked | `xattr -cr /path/to/Comunicator.app` on a build you trust |
| Not signed in after relaunch | Confirm you didn’t Clear Session; each account is a separate profile |
| No badge / no notification | Check mute; confirm the site shows unread in the title; reload the tab |
| Call / camera fails | Grant camera & mic to Comunicator in System Settings → Privacy & Security |
| Site looks wrong / won’t load | Reload (`⌘R`); some sites expect Chrome — built-in presets already set that where needed |
| Intel Mac | Published zip is arm64-only; build from source on your machine if needed |

## Build from source

Needs Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open Comunicator.xcodeproj
```

Release zip for sharing:

```bash
./scripts/build-release.sh
```

See the [README](https://github.com/knaps151/Comunicator#build-development) for more detail.

## Support and contributing

- Issues and discussion: [GitHub](https://github.com/knaps151/Comunicator)
- PRs welcome; keep the MIT license and credit **Jono Clark** when redistributing modified builds

## Disclaimer

Use at your own risk and follow each messaging service’s terms of use. Messaging UIs belong to their respective providers; Comunicator only embeds their public web clients.
