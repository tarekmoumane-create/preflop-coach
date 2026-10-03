import AppKit
import CoreGraphics

enum WatchTarget: Equatable {
    case screen
    /// The frontmost window of the app with this name.
    case app(String)
}

enum ScreenGrabber {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    private struct Window {
        let id: CGWindowID
        let owner: String
    }

    /// Normal app windows big enough to hold a table, front to back.
    private static func windows() -> [Window] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        let me = ProcessInfo.processInfo.processIdentifier
        return (list as? [[String: Any]] ?? []).compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  info[kCGWindowOwnerPID as String] as? Int32 != me,
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  bounds["Width"] ?? 0 >= 400, bounds["Height"] ?? 0 >= 300
            else { return nil }
            return Window(id: id, owner: owner)
        }
    }

    static func appsWithWindows() -> [String] {
        var seen = Set<String>()
        return windows().map(\.owner).filter { seen.insert($0).inserted }
    }

    /// `menuBarHeight` is cropped off whole-screen captures so the model never sees our own advice.
    static func capture(_ target: WatchTarget, menuBarHeight: CGFloat) -> CGImage? {
        switch target {
        case .screen:
            var rect = CGDisplayBounds(CGMainDisplayID())
            rect.origin.y += menuBarHeight
            rect.size.height -= menuBarHeight
            // Composite every on-screen window except our own, so the overlay never ends up in the picture.
            let me = ProcessInfo.processInfo.processIdentifier
            let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
            let ids = list.compactMap { info -> CGWindowID? in
                guard info[kCGWindowOwnerPID as String] as? Int32 != me else { return nil }
                return info[kCGWindowNumber as String] as? CGWindowID
            }
            // The array holds the IDs themselves, not boxed numbers.
            let values = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
            let array = values.withUnsafeBufferPointer { buffer in
                CFArrayCreate(nil, UnsafeMutablePointer(mutating: buffer.baseAddress), buffer.count, nil)
            }
            guard let array else { return nil }
            return CGImage(windowListFromArrayScreenBounds: rect, windowArray: array, imageOption: [.bestResolution])
        case .app(let name):
            guard let window = windows().first(where: { $0.owner == name }) else { return nil }
            return CGWindowListCreateImage(.null, .optionIncludingWindow, window.id, [.boundsIgnoreFraming, .bestResolution])
        }
    }

    private static let gridWidth = 64
    private static let gridHeight = 36

    /// A tiny grayscale thumbnail, used to tell whether the screen has changed since the last read.
    static func signature(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: gridWidth * gridHeight)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: gridWidth, height: gridHeight, bitsPerComponent: 8,
                                    bytesPerRow: gridWidth, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            context?.interpolationQuality = .low
            context?.draw(image, in: CGRect(x: 0, y: 0, width: gridWidth, height: gridHeight))
        }
        return pixels
    }

    static func changed(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return true }
        var cells = 0
        for i in a.indices where abs(Int(a[i]) - Int(b[i])) > 12 {
            cells += 1
            if cells >= 6 { return true }
        }
        return false
    }

    static func jpeg(_ image: CGImage, maxEdge: Int) -> Data? {
        let scale = min(1, Double(maxEdge) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale))
        let height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
