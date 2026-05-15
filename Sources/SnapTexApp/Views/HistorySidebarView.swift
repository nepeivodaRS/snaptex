import SwiftUI

struct HistorySidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            if model.history.isEmpty {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 30))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(model.history) { entry in
                            HistoryRow(
                                entry: entry,
                                isSelected: entry.id == model.selectedHistoryID,
                                titleFontSize: model.settings.historyTitleFontSize,
                                copy: { model.copyHistoryEntry(entry) },
                                rename: { model.renameHistoryEntry(entry, title: $0) },
                                delete: { model.deleteHistoryEntry(entry) },
                                reopen: { model.reopenHistoryEntry(entry) }
                            )
                            .id(entry.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .onAppear {
                        scrollToSelectedHistoryItem(proxy)
                    }
                    .onChange(of: model.selectedHistoryID) { _ in
                        scrollToSelectedHistoryItem(proxy)
                    }
                    .onChange(of: model.history.first?.id) { _ in
                        scrollToSelectedHistoryItem(proxy)
                    }
                }
            }
        }
    }

    private func scrollToSelectedHistoryItem(_ proxy: ScrollViewProxy) {
        guard let id = model.selectedHistoryID ?? model.history.first?.id else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: OCRHistoryEntry
    let isSelected: Bool
    let titleFontSize: Int
    let copy: () -> Void
    let rename: (String) -> Void
    let delete: () -> Void
    let reopen: () -> Void

    @State private var isRenaming = false
    @State private var draftTitle = ""
    @FocusState private var titleFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(entry.timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isRenaming {
                    TextField("Name", text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .focused($titleFieldFocused)
                        .onAppear {
                            titleFieldFocused = true
                        }
                        .onSubmit(saveRename)

                    HistoryActionButton(systemName: "checkmark", help: "Save name", tint: .green, action: saveRename)
                    HistoryActionButton(systemName: "xmark", help: "Cancel", action: cancelRename)
                } else {
                    Button(action: reopen) {
                        HStack(spacing: 5) {
                            stateIndicator
                            Text(entry.title)
                                .font(.system(size: CGFloat(titleFontSize), weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Reopen and edit")

                    HStack(spacing: 4) {
                        HistoryActionButton(systemName: "doc.on.doc", help: "Copy again", action: copy)
                        HistoryActionButton(systemName: "square.and.pencil", help: "Rename", action: beginRename)
                        HistoryActionButton(systemName: "trash", help: "Delete", tint: .red, action: delete)
                    }
                }
            }

            Button(action: reopen) {
                thumbnail
            }
            .buttonStyle(.plain)
            .help("Reopen and edit")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch entry.state {
        case .recognizing:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 12, height: 12)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
        case .recognized:
            EmptyView()
        }
    }

    private func beginRename() {
        draftTitle = entry.title
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = true
        }
    }

    private func saveRename() {
        rename(draftTitle)
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private func cancelRename() {
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary.opacity(0.45))

            if let image = entry.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "function")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct HistoryActionButton: View {
    let systemName: String
    let help: String
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(HistoryActionButtonStyle(isHovered: isHovered, tint: tint))
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct HistoryActionButtonStyle: ButtonStyle {
    let isHovered: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered || configuration.isPressed ? tint : .secondary)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(configuration.isPressed ? 0.24 : isHovered ? 0.14 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
