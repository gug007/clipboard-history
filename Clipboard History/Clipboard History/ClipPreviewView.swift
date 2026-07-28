import AppKit
import SwiftUI

/// Full-content inspector for the highlighted clip.
///
/// The list can only ever show a two-line excerpt, so before this existed the
/// only way to find out what a long clip actually contained was to paste it
/// somewhere and look. Opened with Cmd-Y, closed with Escape.
struct ClipPreviewView: View {
    let item: ClipItem
    let store: HistoryStore
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    @State private var payloads: [ClipPayload] = []
    @State private var didLoad = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().opacity(0.18)
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .task(id: item.id) {
            didLoad = false
            payloads = (try? store.payloads(for: item.entry.id)) ?? []
            didLoad = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: kindIcon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.entry.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(metadataLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close preview (⎋)")
            .accessibilityLabel("Close preview")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var metadataLine: String {
        var parts: [String] = [kindLabel]
        if let source = item.entry.sourceAppName {
            parts.append(source)
        }
        parts.append(
            item.entry.createdAt.formatted(date: .abbreviated, time: .shortened)
        )
        if item.entry.byteSize > 0 {
            parts.append(item.entry.byteSize.formatted(.byteCount(style: .file)))
        }
        if item.isStale {
            parts.append("moved or deleted")
        }
        return parts.joined(separator: " · ")
    }

    private var kindLabel: String {
        switch item.entry.kind {
        case .text:      return "Text"
        case .url:       return "Link"
        case .richText:  return "Formatted text"
        case .image:     return "Image"
        case .file:      return "File"
        case .multiFile: return "\(payloads.count) files"
        }
    }

    private var kindIcon: String {
        switch item.entry.kind {
        case .text:      return "textformat"
        case .url:       return "link"
        case .richText:  return "doc.richtext"
        case .image:     return "photo"
        case .file:      return "doc"
        case .multiFile: return "doc.on.doc"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch item.entry.kind {
        case .text, .url:
            textBody(item.entry.searchableText, monospaced: true)
        case .richText:
            richTextBody
        case .image:
            imageBody
        case .file, .multiFile:
            fileBody
        }
    }

    /// Vertical-only on purpose: a two-axis ScrollView centres content that
    /// fits, which parks a short clip in the middle of an empty card.
    private func textBody(_ text: String, monospaced: Bool) -> some View {
        ScrollView(.vertical) {
            Text(text)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(14)
        }
    }

    @ViewBuilder
    private var richTextBody: some View {
        let plain = payloads.first?.inlineText ?? item.entry.searchableText
        if let attributed = attributedRichText {
            ScrollView {
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        } else {
            textBody(plain, monospaced: false)
        }
    }

    /// Rich text is stored as its original pasteboard bytes. RTF converts
    /// cleanly and offline; HTML would drag in a WebKit parse on the main
    /// thread, so that case falls back to the plain-text representation.
    private var attributedRichText: AttributedString? {
        guard let payload = payloads.first,
              let data = payload.inlineData,
              !data.isEmpty,
              payload.dataFormat == NSPasteboard.PasteboardType.rtf.rawValue
                || payload.uti == NSPasteboard.PasteboardType.rtf.rawValue,
              let ns = NSAttributedString(rtf: data, documentAttributes: nil)
        else { return nil }
        return try? AttributedString(ns, including: \.appKit)
    }

    @ViewBuilder
    private var imageBody: some View {
        if let data = payloads.first?.inlineData, let image = NSImage(data: data) {
            ScrollView(.vertical) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(14)
            }
        } else {
            placeholder(didLoad ? "This image is no longer available." : "Loading…")
        }
    }

    @ViewBuilder
    private var fileBody: some View {
        if payloads.isEmpty {
            placeholder(didLoad ? "No files are attached to this clip." : "Loading…")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(payloads) { payload in
                        HStack(alignment: .top, spacing: 10) {
                            fileIcon(for: payload)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payload.filename ?? "Untitled")
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(displayPath(for: payload))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                            Text(payload.byteSize.formatted(.byteCount(style: .file)))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private func fileIcon(for payload: ClipPayload) -> some View {
        if let data = payload.iconPNG, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "doc")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }

    private func displayPath(for payload: ClipPayload) -> String {
        guard let raw = payload.fileURLString,
              let url = URL(string: raw)
        else { return payload.filename ?? "" }
        return url.deletingLastPathComponent().path(percentEncoded: false)
    }

    private func placeholder(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            // No .keyboardShortcut here: the overlay's key handler already
            // owns Return and Cmd-C, and a second claimant would make which
            // one runs depend on AppKit's key-equivalent ordering.
            Button(action: onPaste) {
                Label("Paste", systemImage: "return")
            }
            .controlSize(.small)
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .controlSize(.small)
            Spacer()
            Text("⎋ closes this preview")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
