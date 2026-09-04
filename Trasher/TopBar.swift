import SwiftUI

struct TopBar: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        HStack(spacing: 16) {
            gridSizeSlider

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Text(store.mode == .trash ? "Trash" : "Sandbox")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white.opacity(0.8))
                if store.mode == .select {
                    FilterTabs()
                } else {
                    statusLabel
                }
            }

            Spacer(minLength: 12)

            if store.mode != .select || store.selectedCount > 0 {
                Button(store.mode == .trash ? "Back" : "Cancel") {
                    store.cancel()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
            }

            if store.mode == .trash, store.selectedCount > 0 {
                Button("Restore") {
                    Task { await store.restoreSelected() }
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(.black)
                .background(.white, in: Capsule())
                .disabled(store.isBusy)
            } else if store.mode == .trash, store.trashedCount > 0 {
                Button("Empty Trash") {
                    Task { await store.emptyTrash() }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .disabled(store.isBusy)
            } else if store.mode == .select, store.selectedCount > 0 {
                commitButton
            }

            trashButton
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background {
            Rectangle()
                .fill(barFill)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }

    private var gridSizeSlider: some View {
        @Bindable var store = store
        return HStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Slider(value: $store.columnCount, in: 3...10, step: 1)
                .controlSize(.small)
                .frame(width: 140)
                .tint(.white.opacity(0.85))
            Image(systemName: "square.grid.4x3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
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
            .padding(.vertical, 5)
            .foregroundStyle(.black)
            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if store.selectedCount == 0 {
            Text(store.trashedCount == 1 ? "1 photo" : "\(store.trashedCount) photos")
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Text("\(store.selectedCount) selected")
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var barFill: Color {
        switch store.mode {
        case .trash:
            Color(red: 0.14, green: 0.08, blue: 0.06)
        case .select:
            Color.black
        }
    }

    private var trashButton: some View {
        Button {
            if store.mode == .trash {
                store.cancel()
            } else {
                store.openTrash()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.mode == .trash ? "trash.fill" : "trash")
                    .font(.system(size: 12, weight: .semibold))
                if store.trashedCount > 0 {
                    Text("\(store.trashedCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                store.mode == .trash ? Color.white.opacity(0.16) : Color.white.opacity(0.08),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .help("Recently Deleted")
    }
}

private struct FilterTabs: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            tab(.all, title: "All", count: store.photos.count)
            tab(.keep, title: "Keep", count: store.selectedCount)
            tab(.delete, title: "Delete", count: store.pendingDeleteCount)
        }
        .padding(2)
        .background(.white.opacity(0.08), in: Capsule())
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
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(.white.opacity(selected ? 0.95 : 0.72))
                .background(selected ? Color.white.opacity(0.16) : Color.clear, in: Capsule())
                .opacity(enabled ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(enabled ? "\(title) photos" : "Nothing to show")
    }
}
