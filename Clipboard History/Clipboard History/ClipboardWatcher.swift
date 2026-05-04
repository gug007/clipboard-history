import AppKit
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
                self?.tick()
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

    private func tick() {
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
        if let bundleId = app?.bundleIdentifier, Self.skippedSourceApps.contains(bundleId) {
            return
        }

        // Files take priority over text (Finder, save dialogs).
        if let fileEvent = captureFiles(pb: pb, app: app) {
            onCapture(.files(fileEvent))
            return
        }

        if let textEvent = captureText(pb: pb, app: app) {
            onCapture(.text(textEvent))
            return
        }
    }

    private func captureFiles(pb: NSPasteboard, app: NSRunningApplication?) -> CapturedFileEvent? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard
            let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
            !urls.isEmpty
        else { return nil }

        let fileInfos: [CapturedFileEvent.FileInfo] = urls.compactMap { url in
            let standardized = url.standardizedFileURL

            let bookmarkData = try? standardized.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let values = try? standardized.resourceValues(forKeys: [
                .totalFileSizeKey, .fileSizeKey, .isDirectoryKey, .contentTypeKey, .contentModificationDateKey
            ])
            let byteSize = Int64(values?.totalFileSize ?? values?.fileSize ?? 0)
            let isDirectory = values?.isDirectory ?? false
            let uti = values?.contentType?.identifier
            let mtime = values?.contentModificationDate ?? Date()

            return CapturedFileEvent.FileInfo(
                url: standardized,
                bookmarkData: bookmarkData,
                displayName: standardized.lastPathComponent,
                byteSize: byteSize,
                isDirectory: isDirectory,
                uti: uti,
                iconPNG: Self.iconPNG(for: standardized),
                mtime: mtime
            )
        }

        guard !fileInfos.isEmpty else { return nil }

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

    private static func iconPNG(for url: URL, size: CGFloat = 64) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        guard let tiff = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static let skippedTypes: [String] = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
        "Hide"
    ]

    private static let skippedSourceApps: Set<String> = [
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.5",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.lastpass.LastPassMacApp",
        "org.keepassxc.keepassxc"
    ]
}
