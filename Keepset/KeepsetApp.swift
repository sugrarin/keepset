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
            CommandMenu("Folder") {
                Button("Choose Folder…") {
                    Task { await store.chooseFolderWithPanel() }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Show Folder in Finder") {
                    if let directory = store.directory {
                        NSWorkspace.shared.open(directory)
                    }
                }
                .disabled(!store.hasFolder)

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
