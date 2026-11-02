import AppKit
import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                helpSection("Getting started") {
                    numbered([
                        "Pick a service in the sidebar (WhatsApp, Google Messages, Slack, Messenger, Telegram).",
                        "Sign in inside the embedded browser as you would on the web.",
                        "Use Custom URL… for another HTTPS messaging site.",
                        "Add another login with ⋯ → Add Account… — each account stays isolated."
                    ])
                }

                helpSection("Accounts and sessions") {
                    bullet([
                        ("Add Account", "Creates a new profile with its own cookies and storage."),
                        ("Rename", "Double-click a tab, use the context menu, or Session → Rename Tab… (⇧⌘R)."),
                        ("Clear Session Cookies…", "Signs you out in Comunicator by wiping that profile’s site data."),
                        ("Delete Account", "Removes the profile, open tab, and login data. Cannot be undone.")
                    ])
                }

                helpSection("Tabs and shortcuts") {
                    shortcutTable([
                        ("⌘1 – ⌘9", "Switch to tab 1–9"),
                        ("⌘R", "Reload active tab"),
                        ("⇧⌘R", "Rename active tab"),
                        ("⇧⌘M", "Mute / unmute notifications")
                    ])
                    Text("Open tabs stay live in the background so unread badges can still update. Opening many tabs uses more memory.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                helpSection("Notifications") {
                    Text("Desktop banners and the dock badge use unread counts when they appear in the page title (patterns like (3), 3 ·, or [3]). Mute a tab from the toolbar or Session menu. Click a notification to focus that tab.")
                        .font(.body)
                    Text("Services that don’t put a count in the window title may not badge or notify reliably.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                helpSection("Custom URLs, camera & files") {
                    bullet([
                        ("Custom URL", "Must be HTTPS. Some SSO or media flows may be limited on unknown hosts."),
                        ("Camera & mic", "Allowed for in-page calls after macOS permission prompts, on allowed origins only."),
                        ("Downloads / uploads", "Use the standard macOS save and open panels.")
                    ])
                }

                helpSection("Troubleshooting") {
                    bullet([
                        ("“Not Opened” / malware warning", "Click Done, then System Settings → Privacy & Security → Open Anyway."),
                        ("Still blocked", "Right-click → Open, or on a build you trust: xattr -cr /path/to/Comunicator.app"),
                        ("No badge / notification", "Check mute, confirm unread in the title, then reload (⌘R)."),
                        ("Camera fails", "Grant camera and microphone to Comunicator in System Settings.")
                    ])
                }

                Divider()

                HStack(spacing: 12) {
                    Button("Online Help…") {
                        openURL("https://knaps151.github.io/Comunicator/help.html")
                    }
                    Button("GitHub Releases…") {
                        openURL("https://github.com/knaps151/Comunicator/releases")
                    }
                    Spacer()
                }
                .buttonStyle(.link)

                Text("Unofficial third-party client shell. Not affiliated with Meta, Google, Slack, Telegram, or Apple. Use at your own risk and follow each service’s terms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(minWidth: 480, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Comunicator Help")
                .font(.largeTitle.weight(.bold))
            Text("Version \(appVersion)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Native macOS shell for web messaging apps — isolated tabs, desktop notifications, and per-account sessions.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private func helpSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
    }

    private func numbered(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fontWeight(.semibold)
                        .frame(width: 18, alignment: .trailing)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.body)
    }

    private func bullet(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.body.weight(.semibold))
                    Text(item.1)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func shortcutTable(_ rows: [(String, String)]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    Text(row.0)
                        .font(.body.monospaced())
                        .fontWeight(.medium)
                    Text(row.1)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    HelpView()
}
