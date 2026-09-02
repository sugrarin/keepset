import SwiftUI

struct TopBar: View {
    @Environment(PhotoStore.self) private var store

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 16) {
            Color.clear
                .frame(width: 72, height: 12)

            gridSizeSlider

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Text("Sandbox")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white.opacity(0.8))
                statusLabel
            }

            Spacer(minLength: 12)

            if store.mode == .confirm || store.selectedCount > 0 {
                Button("Cancel") {
                    store.cancel()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
            }

            if store.mode == .confirm {
                Button("Yes, fine!") {
                    Task { await store.confirmKeep() }
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(store.selectedCount == 0 ? Color.white.opacity(0.12) : Color(red: 0.22, green: 0.72, blue: 0.42), in: Capsule())
                .disabled(store.selectedCount == 0 || store.isBusy)
            } else if store.selectedCount > 0 {
                Button("Keep") {
                    store.keep()
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(.black)
                .background(.white, in: Capsule())
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.trailing, 16)
        .frame(height: 54)
        .background {
            Rectangle()
                .fill(store.mode == .confirm
                    ? Color(red: 0.06, green: 0.14, blue: 0.09)
                    : Color.black)
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

    @ViewBuilder
    private var statusLabel: some View {
        switch store.mode {
        case .select:
            if store.selectedCount == 0 {
                Text(store.photos.count == 1 ? "1 photo" : "\(store.photos.count) photos")
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("\(store.selectedCount) selected")
                    .foregroundStyle(.white.opacity(0.85))
            }
        case .confirm:
            Text(confirmCopy)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var confirmCopy: String {
        let keep = store.selectedCount
        let drop = store.pendingDeleteCount
        if keep == 0 {
            return "Nothing selected to keep"
        }
        if drop == 0 {
            return keep == 1 ? "Keep this photo" : "Keep these \(keep) photos"
        }
        return "Keep \(keep), move \(drop) to Trash"
    }
}
