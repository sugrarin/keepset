import AppKit
import SwiftUI

@main
struct KeepsetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = PhotoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1280, height: 840)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Sandbox") {
                Button("Reset Demo Photos") {
                    Task { await store.resetSandbox() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(WorkingPhotosDirectory.seedURL == nil || !store.isSandboxFolder)

                Button("Choose Folder…") {
                    Task { await store.chooseFolderWithPanel() }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Use Default Folder") {
                    Task { await store.useDefaultFolder() }
                }

                Button("Show Photos Folder") {
                    NSWorkspace.shared.open(store.directory)
                }

                Button("Recently Deleted") {
                    store.openTrash()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
