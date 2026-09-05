import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(PhotoStore.self) private var store
    @State private var previewPhoto: Photo?

    var body: some View {
        VStack(spacing: 0) {
            TopBar()

            ZStack {
                Theme.canvas

                PhotoGridView(
                    photos: store.displayedPhotos,
                    columns: store.columns,
                    selectedIDs: store.selectedIDs,
                    isDragSelecting: store.isDragSelecting,
                    onToggle: store.toggle,
                    onPreview: { previewPhoto = $0 },
                    onDragSelect: { photo in
                        previewPhoto = nil
                        store.handleDragSelect(at: photo)
                    },
                    onDragSelectEnd: store.endDragSelect
                )
                .opacity(store.displayedPhotos.isEmpty ? 0 : 1)

                if store.isBusy, store.displayedPhotos.isEmpty {
                    ProgressView()
                        .controlSize(.large)
                } else if store.displayedPhotos.isEmpty {
                    switch store.mode {
                    case .trash:
                        EmptyTrashView()
                    case .sandbox where store.photos.isEmpty:
                        EmptySandboxView {
                            Task { await store.resetSandbox() }
                        }
                    case .cameraRoll:
                        EmptyCameraRollView(access: store.cameraRollAccess) {
                            openPhotosPrivacySettings()
                        }
                    case .sandbox:
                        EmptyView()
                    }
                }
            }
            .clipped()
        }
        .background(Theme.canvas)
        .overlay {
            if let previewPhoto {
                PreviewOverlay(photo: previewPhoto)
                    .allowsHitTesting(false)
            }
        }
        .background(WindowConfigurator())
        .animation(.snappy(duration: 0.28), value: store.mode)
        .animation(.snappy(duration: 0.28), value: store.displayedPhotos.map(\.id))
        .task { await store.load() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .background {
            Button("Select All") { store.selectAll() }
                .keyboardShortcut("a", modifiers: .command)
                .hidden()
            Button("Escape") { handleEscape() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
            Button("Confirm") { handleReturn() }
                .keyboardShortcut(.return, modifiers: [])
                .hidden()
        }
        .onChange(of: store.mode) { _, _ in
            previewPhoto = nil
        }
        .onChange(of: store.filter) { _, _ in
            previewPhoto = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard store.mode == .cameraRoll, store.cameraRollAccess != .authorized else { return }
            Task { await store.loadCameraRoll() }
        }
    }

    private func handleEscape() {
        if previewPhoto != nil {
            previewPhoto = nil
            return
        }
        store.cancel()
    }

    private func handleReturn() {
        switch store.mode {
        case .sandbox where store.selectedCount > 0, .cameraRoll where store.selectedCount > 0:
            Task { await store.keep() }
        case .trash where store.selectedCount > 0:
            Task { await store.restoreSelected() }
        case .sandbox, .cameraRoll, .trash:
            break
        }
    }

    private func openPhotosPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Photos",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

private struct EmptyTrashView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text("Trash is empty")
                .font(.title3.weight(.medium))
            Text("Photos you drop while keeping will land here, so you can restore a mistake.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyCameraRollView: View {
    let access: PhotoAccess
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text("Camera Roll")
                .font(.title3.weight(.medium))
            Text(copy)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if access == .denied {
                Button("Open System Settings", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var copy: String {
        switch access {
        case .denied:
            "Trasher needs access to Photos to show Camera Roll."
        case .authorized:
            "Camera Roll is empty."
        case .unknown:
            "Checking Photos access…"
        }
    }
}

private struct EmptySandboxView: View {
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text("No photos in the sandbox")
                .font(.title3.weight(.medium))
            Text("Reset to restore the demo folder.")
                .foregroundStyle(.secondary)
            Button("Reset Demo Photos", action: onReset)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(Theme.onAccent)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowHookView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowHookView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = Theme.canvasNS
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 760, height: 520)
        if let titlebar = window.standardWindowButton(.closeButton)?.superview {
            titlebar.wantsLayer = true
            titlebar.layer?.backgroundColor = Theme.canvasNS.cgColor
        }
    }
}
