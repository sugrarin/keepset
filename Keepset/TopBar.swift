import SwiftUI

private enum BarControl {
    static let height: CGFloat = 38
    static let radius: CGFloat = 10
    static let barHeight: CGFloat = 58

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

struct TopBar: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                gridSizeSlider
                TileShapeToggle()
                if store.mode == .sandbox || store.mode == .cameraRoll {
                    FilterTabs()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FolderPicker()

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                trailingActions
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: BarControl.barHeight)
        .background(Theme.canvas)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.12)
        }
    }

    private var gridSizeSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.grid.4x3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Slider(value: invertedColumnCount, in: 3...10, step: 1)
                .controlSize(.small)
                .frame(width: 140)
                .tint(Theme.accent)
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var invertedColumnCount: Binding<Double> {
        Binding(
            get: { 13 - store.columnCount },
            set: { store.columnCount = 13 - $0 }
        )
    }

    @ViewBuilder
    private var trailingActions: some View {
        if store.mode == .sandbox || store.mode == .cameraRoll, store.selectedCount > 0 {
            chromeButton("Cancel", fill: Theme.surface) {
                store.cancel()
            }
            commitButton
        } else if store.mode == .trash, store.selectedCount > 0 {
            chromeButton("Restore", fill: Theme.accent, foreground: Theme.onAccent, emphasized: true) {
                Task { await store.restoreSelected() }
            }
            .disabled(store.isBusy)
            .allowsHitTesting(!store.isBusy)
        } else if store.mode == .trash, store.trashedCount > 0 {
            chromeButton("Empty Trash", fill: Theme.surface) {
                Task { await store.emptyTrash() }
            }
            .disabled(store.isBusy)
            .allowsHitTesting(!store.isBusy)
        } else if store.mode == .sandbox, let deletion = store.lastDeletion {
            Text("Deleted \(deletion.count)")
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
            chromeButton("Undo", fill: Theme.accent, foreground: Theme.onAccent, emphasized: true) {
                Task { await store.undoDelete() }
            }
            .disabled(store.isBusy)
            .allowsHitTesting(!store.isBusy)
        }
    }

    private var commitButton: some View {
        Button {
            Task { await store.keep() }
        } label: {
            VStack(spacing: 1) {
                Text("Keep \(store.selectedCount)")
                    .font(.system(size: 13, weight: .semibold))
                Text("Delete \(store.pendingDeleteCount)")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.55)
            }
            .padding(.horizontal, 14)
            .frame(height: BarControl.height)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: BarControl.shape)
            .contentShape(BarControl.shape)
        }
        .buttonStyle(FillHitButtonStyle())
        .disabled(store.isBusy)
        .allowsHitTesting(!store.isBusy)
    }

    private func chromeButton(
        _ title: String,
        fill: Color,
        foreground: Color = .white,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: emphasized ? .semibold : .medium))
                .padding(.horizontal, 14)
                .frame(height: BarControl.height)
                .foregroundStyle(foreground)
                .background(fill, in: BarControl.shape)
                .contentShape(BarControl.shape)
        }
        .buttonStyle(FillHitButtonStyle())
    }
}

private struct FolderPicker: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        Menu {
            Picker("Workspace", selection: workspaceBinding) {
                ForEach(WorkspaceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 5) {
                Text(store.mode.title)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: BarControl.height)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("Choose a working folder")
    }

    private var workspaceBinding: Binding<WorkspaceMode> {
        Binding(
            get: { store.mode },
            set: { store.setWorkspace($0) }
        )
    }
}

private struct TileShapeToggle: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            option(.square, symbol: "square", help: "Square tiles")
            option(.original, symbol: "rectangle.portrait", help: "Original shape")
        }
        .padding(3)
        .frame(height: BarControl.height)
        .background(Theme.surface, in: BarControl.shape)
    }

    private func option(_ shape: TileShape, symbol: String, help: String) -> some View {
        let selected = store.tileShape == shape
        return Button {
            store.tileShape = shape
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.white.opacity(selected ? 0.95 : 0.6))
                .background(selected ? Theme.canvas : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(FillHitButtonStyle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FilterTabs: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            tab(.all, title: "All", count: store.workingPhotos.count)
            tab(.keep, title: "Keep", count: store.selectedCount)
            tab(.delete, title: "Delete", count: store.pendingDeleteCount)
        }
        .padding(3)
        .frame(height: BarControl.height)
        .background(Theme.surface, in: BarControl.shape)
    }

    private func tab(_ filter: PhotoFilter, title: String, count: Int) -> some View {
        let enabled = store.isFilterEnabled(filter)
        let selected = store.filter == filter
        return Button {
            store.setFilter(filter)
        } label: {
            Text("\(title) \(count)")
                .font(.system(size: 12, weight: selected ? .semibold : .medium))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.white.opacity(selected ? 0.95 : 0.72))
                .background(selected ? Theme.canvas : Color.clear, in: Capsule())
                .contentShape(Capsule())
                .opacity(enabled ? 1 : 0.38)
        }
        .buttonStyle(FillHitButtonStyle())
        .disabled(!enabled)
        .allowsHitTesting(enabled)
        .help(enabled ? "\(title) photos" : "Nothing to show")
    }
}

private struct FillHitButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onTapGesture(perform: configuration.trigger)
    }
}
