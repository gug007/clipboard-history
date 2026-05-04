import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct CapturedTextEvent {
    let text: String
    let sourceApp: String?
    let sourceAppName: String?
    let timestamp: Date
}

struct CapturedFileEvent {
    struct FileInfo {
        let url: URL
        let bookmarkData: Data?
        let displayName: String
        let byteSize: Int64
        let isDirectory: Bool
        let uti: String?
        let iconPNG: Data?
        let mtime: Date
    }
    let files: [FileInfo]
    let sourceApp: String?
    let sourceAppName: String?
    let timestamp: Date
}

enum CapturedEvent {
    case text(CapturedTextEvent)
    case files(CapturedFileEvent)
}

@MainActor
final class ClipboardWatcher {
    private var lastChangeCount: Int
    private var timer: Timer?
    private let onCapture: (CapturedEvent) -> Void
    private(set) var isPaused: Bool = false

    init(onCapture: @escaping (CapturedEvent) -> Void) {
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.onCapture = onCapture
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setPaused(_ paused: Bool) { isPaused = paused }

    private func tick() async {
        guard !isPaused else { return }
        let pb = NSPasteboard.general
        let current = pb.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if let types = pb.types {
            for skip in Self.skippedTypes where types.contains(NSPasteboard.PasteboardType(skip)) {
                _ = skip
                return
            }
        }

        let app = NSWorkspace.shared.frontmostApplication
        if let bundleId = app?.bundleIdentifier,
           AppSettings.shared.excludedApps.contains(bundleId) {
            return
        }

        if let fileEvent = await captureFiles(pb: pb, app: app) {
            onCapture(.files(fileEvent))
            return
        }

        if let textEvent = captureText(pb: pb, app: app) {
            onCapture(.text(textEvent))
            return
        }
    }

    private func captureFiles(pb: NSPasteboard, app: NSRunningApplication?) async -> CapturedFileEvent? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard
            let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
            !urls.isEmpty
        else { return nil }

        // Phase 1: synchronous metadata + bookmark while pasteboard sandbox extension is alive.
        struct Partial {
            let url: URL
            let bookmarkData: Data?
            let displayName: String
            let byteSize: Int64
            let isDirectory: Bool
            let uti: String?
            let mtime: Date
        }

        let partials: [Partial] = urls.compactMap { url in
            let standardized = url.standardizedFileURL
            let bookmarkData = try? standardized.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let values = try? standardized.resourceValues(forKeys: [
                .totalFileSizeKey, .fileSizeKey, .isDirectoryKey,
                .contentTypeKey, .contentModificationDateKey
            ])
            return Partial(
                url: standardized,
                bookmarkData: bookmarkData,
                displayName: standardized.lastPathComponent,
                byteSize: Int64(values?.totalFileSize ?? values?.fileSize ?? 0),
                isDirectory: values?.isDirectory ?? false,
                uti: values?.contentType?.identifier,
                mtime: values?.contentModificationDate ?? Date()
            )
        }

        guard !partials.isEmpty else { return nil }

        // Phase 2: async thumbnail generation (real image previews / PDF pages / etc.).
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        var fileInfos: [CapturedFileEvent.FileInfo] = []
        for partial in partials {
            let thumb = await Self.thumbnailPNG(for: partial.url, scale: scale)
                ?? Self.fallbackIconPNG(for: partial.url)
            fileInfos.append(
                CapturedFileEvent.FileInfo(
                    url: partial.url,
                    bookmarkData: partial.bookmarkData,
                    displayName: partial.displayName,
                    byteSize: partial.byteSize,
                    isDirectory: partial.isDirectory,
                    uti: partial.uti,
                    iconPNG: thumb,
                    mtime: partial.mtime
                )
            )
        }

        return CapturedFileEvent(
            files: fileInfos,
            sourceApp: app?.bundleIdentifier,
            sourceAppName: app?.localizedName,
            timestamp: Date()
        )
    }

    private func captureText(pb: NSPasteboard, app: NSRunningApplication?) -> CapturedTextEvent? {
        guard let text = pb.string(forType: .string), !text.isEmpty else { return nil }
        return CapturedTextEvent(
            text: text,
            sourceApp: app?.bundleIdentifier,
            sourceAppName: app?.localizedName,
            timestamp: Date()
        )
    }

    private static func thumbnailPNG(for url: URL, size: CGFloat = 128, scale: CGFloat) async -> Data? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: NSSize(width: size, height: size),
            scale: scale,
            representationTypes: .all
        )
        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return pngData(from: rep.nsImage)
        } catch {
            return nil
        }
    }

    private static func fallbackIconPNG(for url: URL, size: CGFloat = 128) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        return pngData(from: icon)
    }

    private static func pngData(from image: NSImage) -> Data? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            return rep.representation(using: .png, properties: [:])
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static let skippedTypes: [String] = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
        "Hide"
    ]

}
