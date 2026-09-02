import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(PhotoStore.self) private var store
    @State private var previewPhoto: Photo?

    var body: some View {
        VStack(spacing: 0) {
            TopBar()

            ZStack {
                Color.black

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
                .opacity(store.photos.isEmpty ? 0 : 1)

                if store.photos.isEmpty, !store.isBusy {
                    EmptySandboxView {
                        Task { await store.resetSandbox() }
                    }
                }
            }
            .clipped()
        }
        .background(Color.black)
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
        case .select where store.selectedCount > 0:
            store.keep()
        case .confirm where store.selectedCount > 0:
            Task { await store.confirmKeep() }
        case .select, .confirm:
            break
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
        window.backgroundColor = .black
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 760, height: 520)
        if let titlebar = window.standardWindowButton(.closeButton)?.superview {
            titlebar.wantsLayer = true
            titlebar.layer?.backgroundColor = NSColor.black.cgColor
        }
    }
}
