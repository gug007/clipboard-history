import AppKit
import ImageIO
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct CapturedTextEvent {
    let text: String
    let sourceApp: String?
    let sourceAppName: String?
    let timestamp: Date
}

struct CapturedRichTextEvent {
    let data: Data
    let pasteboardType: String
    let uti: String
    let plainText: String
    let sourceApp: String?
    let sourceAppName: String?
    let timestamp: Date
}

struct CapturedImageEvent {
    let data: Data
    let pasteboardType: String
    let uti: String
    let iconPNG: Data?
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
    case richText(CapturedRichTextEvent)
    case image(CapturedImageEvent)
    case files(CapturedFileEvent)
}

@MainActor
final class ClipboardWatcher {
    private struct PendingObservation {
        let changeCount: Int
        let timestamp: Date
    }

    private var lastChangeCount: Int
    private var timer: Timer?
    private var captureLoopIsRunning = false
    private var captureGeneration: UInt = 0
    private var pendingObservation: PendingObservation?
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
                self?.requestCaptureTick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        captureGeneration &+= 1

        // A pause boundary is also a pasteboard boundary. Advancing the
        // baseline both when pausing and resuming guarantees that a value
        // copied at any point during the pause can never be captured later.
        lastChangeCount = NSPasteboard.general.changeCount
        pendingObservation = nil
    }

    /// Timer callbacks may arrive while thumbnail generation is suspended.
    /// Keep one capture loop alive and coalesce observations to the newest
    /// pasteboard change instead of starting re-entrant capture tasks.
    private func requestCaptureTick() {
        let current = NSPasteboard.general.changeCount
        guard !isPaused else {
            lastChangeCount = current
            pendingObservation = nil
            return
        }
        guard current != lastChangeCount else { return }

        if pendingObservation?.changeCount != current {
            pendingObservation = PendingObservation(
                changeCount: current,
                timestamp: Date()
            )
        }

        guard !captureLoopIsRunning else { return }
        captureLoopIsRunning = true
        Task { @MainActor [weak self] in
            await self?.drainPasteboardChanges()
        }
    }

    private func drainPasteboardChanges() async {
        while !isPaused {
            let pb = NSPasteboard.general
            let current = pb.changeCount
            guard current != lastChangeCount else { break }

            // Preserve the time at which this exact pasteboard generation
            // was first observed. File thumbnails can take long enough for
            // later timer ticks and clipboard changes to occur.
            let capturedAt: Date
            if let pendingObservation,
               pendingObservation.changeCount == current {
                capturedAt = pendingObservation.timestamp
            } else {
                capturedAt = Date()
            }
            pendingObservation = nil
            lastChangeCount = current
            let generation = captureGeneration

            if let types = pb.types,
               types.contains(where: Self.skippedTypes.contains) {
                continue
            }

            let app = NSWorkspace.shared.frontmostApplication
            if let bundleId = app?.bundleIdentifier,
               AppSettings.shared.excludedApps.contains(bundleId) {
                continue
            }

            if let fileEvent = await captureFiles(
                pb: pb,
                app: app,
                timestamp: capturedAt
            ) {
                // A pause followed by a quick resume can occur while Quick
                // Look is suspended. A generation check (not merely
                // `isPaused`) prevents that in-flight item crossing either
                // pause boundary and being committed afterward.
                if generation == captureGeneration, !isPaused {
                    onCapture(.files(fileEvent))
                }
                continue
            }

            guard generation == captureGeneration, !isPaused else { continue }

            // Respect the producer's relative preference between rich text
            // and images. Plain text is deliberately considered only after
            // richer representations have had a chance to be retained.
            let richOrImageTypes = (pb.types ?? []).filter {
                Self.richTextTypes.contains($0) || Self.imageTypes.contains($0)
            }
            var capturedRicherRepresentation = false
            var attemptedImage = false
            var attemptedRichText = false
            for type in richOrImageTypes {
                if Self.imageTypes.contains(type), !attemptedImage {
                    attemptedImage = true
                    if let imageEvent = captureImage(
                        pb: pb,
                        preferredType: type,
                        app: app,
                        timestamp: capturedAt
                    ) {
                        onCapture(.image(imageEvent))
                        capturedRicherRepresentation = true
                        break
                    }
                }
                if Self.richTextTypes.contains(type), !attemptedRichText {
                    attemptedRichText = true
                    if let richTextEvent = captureRichText(
                        pb: pb,
                        preferredType: type,
                        app: app,
                        timestamp: capturedAt
                    ) {
                        onCapture(.richText(richTextEvent))
                        capturedRicherRepresentation = true
                        break
                    }
                }
            }
            if capturedRicherRepresentation { continue }

            if let textEvent = captureText(
                pb: pb,
                app: app,
                timestamp: capturedAt
            ) {
                onCapture(.text(textEvent))
            }
        }

        captureLoopIsRunning = false

        // No actor hop occurs between the loop's last comparison and this
        // check, but this also makes the no-lost-wakeup invariant explicit.
        if !isPaused, NSPasteboard.general.changeCount != lastChangeCount {
            requestCaptureTick()
        }
    }

    private func captureFiles(
        pb: NSPasteboard,
        app: NSRunningApplication?,
        timestamp: Date
    ) async -> CapturedFileEvent? {
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
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
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
                mtime: values?.contentModificationDate ?? timestamp
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
            timestamp: timestamp
        )
    }

    private func captureImage(
        pb: NSPasteboard,
        preferredType: NSPasteboard.PasteboardType,
        app: NSRunningApplication?,
        timestamp: Date
    ) -> CapturedImageEvent? {
        let candidateTypes = [preferredType] + Self.imageTypes.filter { $0 != preferredType }
        let available = Set(pb.types ?? [])
        for type in candidateTypes where available.contains(type) {
            guard let data = pb.data(forType: type), !data.isEmpty else { continue }
            guard data.count <= payloadLimitBytes else {
                print("[Capture] skipped oversized \(Self.label(for: type)) image (\(data.count) bytes)")
                continue
            }
            let thumbnail = Self.imageThumbnailPNG(from: data)
            let boundedThumbnail = thumbnail.flatMap {
                $0.count <= payloadLimitBytes - data.count ? $0 : nil
            }
            return CapturedImageEvent(
                data: data,
                pasteboardType: type.rawValue,
                uti: Self.uti(for: type),
                iconPNG: boundedThumbnail,
                sourceApp: app?.bundleIdentifier,
                sourceAppName: app?.localizedName,
                timestamp: timestamp
            )
        }
        return nil
    }

    private func captureRichText(
        pb: NSPasteboard,
        preferredType: NSPasteboard.PasteboardType,
        app: NSRunningApplication?,
        timestamp: Date
    ) -> CapturedRichTextEvent? {
        guard let plainText = limitedPlainText(from: pb), !plainText.isEmpty else {
            // Retaining a plain-text representation prevents raw markup from
            // becoming unsearchable or unpasteable in plain-text-only apps.
            return nil
        }

        let plainBytes = plainText.lengthOfBytes(using: .utf8)
        let candidateTypes = [preferredType] + Self.richTextTypes.filter { $0 != preferredType }
        let available = Set(pb.types ?? [])
        for type in candidateTypes where available.contains(type) {
            guard let data = pb.data(forType: type), !data.isEmpty else { continue }
            guard data.count <= payloadLimitBytes else {
                print("[Capture] skipped oversized \(Self.label(for: type)) representation (\(data.count) bytes)")
                continue
            }

            // The setting is an item cap, not a per-column cap. If retaining
            // raw markup plus its safe fallback would exceed it, the caller
            // will capture the plain representation instead.
            guard data.count <= payloadLimitBytes - plainBytes else {
                return nil
            }

            return CapturedRichTextEvent(
                data: data,
                pasteboardType: type.rawValue,
                uti: Self.uti(for: type),
                plainText: plainText,
                sourceApp: app?.bundleIdentifier,
                sourceAppName: app?.localizedName,
                timestamp: timestamp
            )
        }
        return nil
    }

    private func captureText(
        pb: NSPasteboard,
        app: NSRunningApplication?,
        timestamp: Date
    ) -> CapturedTextEvent? {
        guard let text = limitedPlainText(from: pb), !text.isEmpty else { return nil }
        return CapturedTextEvent(
            text: text,
            sourceApp: app?.bundleIdentifier,
            sourceAppName: app?.localizedName,
            timestamp: timestamp
        )
    }

    private func limitedPlainText(from pb: NSPasteboard) -> String? {
        guard let text = pb.string(forType: .string), !text.isEmpty else { return nil }
        let byteCount = text.lengthOfBytes(using: .utf8)
        guard byteCount <= payloadLimitBytes else {
            print("[Capture] skipped oversized plain text (\(byteCount) bytes)")
            return nil
        }
        return text
    }

    private var payloadLimitBytes: Int {
        // The UI constrains this to 1...100 MB. Clamp persisted/manual
        // defaults too so a corrupt preference cannot reintroduce an
        // effectively unbounded pasteboard allocation.
        min(max(AppSettings.shared.perFileSizeCapMB, 1), 100) * 1_048_576
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

    private static func imageThumbnailPNG(
        from data: Data,
        maxPixelSize: Int = 256
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }

        // Refuse implausible dimensions before asking ImageIO to decode.
        // This keeps a compact-on-disk but adversarial image from causing a
        // large thumbnailing allocation.
        if let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
           let height = properties[kCGImagePropertyPixelHeight] as? NSNumber {
            let w = width.doubleValue
            let h = height.doubleValue
            guard w > 0, h > 0,
                  w <= 50_000, h <= 50_000,
                  w * h <= 250_000_000
            else { return nil }
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }
        let representation = NSBitmapImageRep(cgImage: thumbnail)
        guard let png = representation.representation(
            using: .png,
            properties: [:]
        ),
        png.count <= 512 * 1_024
        else { return nil }
        return png
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

    private static func uti(for type: NSPasteboard.PasteboardType) -> String {
        switch type {
        case .png:  return UTType.png.identifier
        case .tiff: return UTType.tiff.identifier
        case .rtf:  return UTType.rtf.identifier
        case .html: return UTType.html.identifier
        default:    return type.rawValue
        }
    }

    private static func label(for type: NSPasteboard.PasteboardType) -> String {
        switch type {
        case .png:  return "PNG"
        case .tiff: return "TIFF"
        case .rtf:  return "RTF"
        case .html: return "HTML"
        default:    return type.rawValue
        }
    }

    private static let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
    private static let richTextTypes: [NSPasteboard.PasteboardType] = [.rtf, .html]

    private static let skippedTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"),
        NSPasteboard.PasteboardType("com.agilebits.onepassword"),
        NSPasteboard.PasteboardType("Hide")
    ]
}
