import SwiftUI

@main
struct ComunicatorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Tab") {
                ForEach(1...9, id: \.self) { number in
                    Button("Go to Tab \(number)") {
                        model.selectTab(at: number - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command)
                }
            }

            CommandMenu("Session") {
                Button("Reload") {
                    model.reloadActiveTab()
                }
                .keyboardShortcut("r", modifiers: [.command])

                if let tab = model.activeTab {
                    Button("Rename Tab…") {
                        model.beginRename(tabId: tab.id)
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                    Button(tab.notificationsMuted ? "Unmute Notifications" : "Mute Notifications") {
                        model.toggleMute(tabId: tab.id)
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                    Divider()

                    Button("Clear Session Cookies…") {
                        model.requestClearSession(for: tab.profileId)
                    }
                }
            }
        }
    }
}
