import AppKit
import Foundation

struct IconSize {
    let fileName: String
    let pixels: Int
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsDirectory = root.appendingPathComponent("src-tauri/icons", isDirectory: true)
let iconsetDirectory = iconsDirectory.appendingPathComponent("Hopdeck.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconsDirectory, withIntermediateDirectories: true)
if FileManager.default.fileExists(atPath: iconsetDirectory.path) {
    try FileManager.default.removeItem(at: iconsetDirectory)
}
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let appSizes = [
    IconSize(fileName: "32x32.png", pixels: 32),
    IconSize(fileName: "128x128.png", pixels: 128),
    IconSize(fileName: "128x128@2x.png", pixels: 256),
    IconSize(fileName: "icon.png", pixels: 1024),
]

let iconsetSizes = [
    IconSize(fileName: "icon_16x16.png", pixels: 16),
    IconSize(fileName: "icon_16x16@2x.png", pixels: 32),
    IconSize(fileName: "icon_32x32.png", pixels: 32),
    IconSize(fileName: "icon_32x32@2x.png", pixels: 64),
    IconSize(fileName: "icon_128x128.png", pixels: 128),
    IconSize(fileName: "icon_128x128@2x.png", pixels: 256),
    IconSize(fileName: "icon_256x256.png", pixels: 256),
    IconSize(fileName: "icon_256x256@2x.png", pixels: 512),
    IconSize(fileName: "icon_512x512.png", pixels: 512),
    IconSize(fileName: "icon_512x512@2x.png", pixels: 1024),
]

for size in appSizes {
    try writeIcon(size: size.pixels, to: iconsDirectory.appendingPathComponent(size.fileName))
}

for size in iconsetSizes {
    try writeIcon(size: size.pixels, to: iconsetDirectory.appendingPathComponent(size.fileName))
}

func writeIcon(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "HopdeckIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap"])
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "HopdeckIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(size: size)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "HopdeckIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    try pngData.write(to: url)
}

func drawIcon(size: Int) {
    let dimension = CGFloat(size)
    let scale = dimension / 1024.0

    let canvas = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    NSColor.clear.setFill()
    canvas.fill()

    let baseRect = NSRect(x: 48 * scale, y: 48 * scale, width: 928 * scale, height: 928 * scale)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 210 * scale, yRadius: 210 * scale)
    shadow(color: NSColor.black.withAlphaComponent(0.33), blur: 34 * scale, y: -16 * scale)
    gradientFill(path: basePath, start: "#122231", end: "#001E27", angle: 90)
    NSShadow().set()

    let glowPath = NSBezierPath(ovalIn: NSRect(x: 92 * scale, y: 520 * scale, width: 620 * scale, height: 360 * scale))
    gradientFill(path: glowPath, start: "#41B6C855", end: "#41B6C800", angle: 35)

    drawDeckLayer(
        rect: NSRect(x: 238 * scale, y: 266 * scale, width: 548 * scale, height: 402 * scale),
        radius: 72 * scale,
        offset: NSPoint(x: -64 * scale, y: -50 * scale),
        alpha: 0.34,
        scale: scale
    )
    drawDeckLayer(
        rect: NSRect(x: 238 * scale, y: 266 * scale, width: 548 * scale, height: 402 * scale),
        radius: 72 * scale,
        offset: NSPoint(x: -32 * scale, y: -24 * scale),
        alpha: 0.52,
        scale: scale
    )

    let terminalRect = NSRect(x: 238 * scale, y: 276 * scale, width: 548 * scale, height: 402 * scale)
    let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 72 * scale, yRadius: 72 * scale)
    shadow(color: NSColor.black.withAlphaComponent(0.34), blur: 28 * scale, y: -12 * scale)
    gradientFill(path: terminalPath, start: "#182D3B", end: "#07141D", angle: 90)
    NSShadow().set()
    stroke(path: terminalPath, color: "#6FE3F255", width: 3 * scale)

    drawWindowControls(origin: NSPoint(x: 314 * scale, y: 604 * scale), scale: scale)
    drawTerminalGlyph(scale: scale)
    drawHopRoute(scale: scale)
}

func drawDeckLayer(rect: NSRect, radius: CGFloat, offset: NSPoint, alpha: CGFloat, scale: CGFloat) {
    let path = NSBezierPath(
        roundedRect: rect.offsetBy(dx: offset.x, dy: offset.y),
        xRadius: radius,
        yRadius: radius
    )
    shadow(color: NSColor.black.withAlphaComponent(0.16), blur: 12 * scale, y: -5 * scale)
    color("#41B6C8").withAlphaComponent(alpha).setFill()
    path.fill()
    NSShadow().set()
}

func drawWindowControls(origin: NSPoint, scale: CGFloat) {
    let colors = ["#EF8A80", "#E5C15D", "#7FD19B"]
    for (index, value) in colors.enumerated() {
        let rect = NSRect(x: origin.x + CGFloat(index) * 48 * scale, y: origin.y, width: 20 * scale, height: 20 * scale)
        color(value).setFill()
        NSBezierPath(ovalIn: rect).fill()
    }
}

func drawTerminalGlyph(scale: CGFloat) {
    strokeLine(
        points: [
            NSPoint(x: 330 * scale, y: 470 * scale),
            NSPoint(x: 394 * scale, y: 512 * scale),
            NSPoint(x: 330 * scale, y: 554 * scale),
        ],
        color: "#DBE7F3",
        width: 26 * scale,
        lineCap: .round,
        lineJoin: .round
    )

    strokeLine(
        points: [
            NSPoint(x: 440 * scale, y: 458 * scale),
            NSPoint(x: 558 * scale, y: 458 * scale),
        ],
        color: "#41B6C8",
        width: 26 * scale,
        lineCap: .round,
        lineJoin: .round
    )
}

func drawHopRoute(scale: CGFloat) {
    let route = NSBezierPath()
    route.move(to: NSPoint(x: 440 * scale, y: 386 * scale))
    route.curve(
        to: NSPoint(x: 676 * scale, y: 506 * scale),
        controlPoint1: NSPoint(x: 498 * scale, y: 324 * scale),
        controlPoint2: NSPoint(x: 626 * scale, y: 362 * scale)
    )
    stroke(path: route, color: "#41B6C8", width: 20 * scale, lineCap: .round, lineJoin: .round)

    drawNode(center: NSPoint(x: 420 * scale, y: 390 * scale), radius: 34 * scale, fill: "#41B6C8", strokeColor: "#D7F8FF", scale: scale)
    drawNode(center: NSPoint(x: 548 * scale, y: 406 * scale), radius: 24 * scale, fill: "#001E27", strokeColor: "#41B6C8", scale: scale)
    drawNode(center: NSPoint(x: 690 * scale, y: 512 * scale), radius: 42 * scale, fill: "#41B6C8", strokeColor: "#D7F8FF", scale: scale)
}

func drawNode(center: NSPoint, radius: CGFloat, fill: String, strokeColor: String, scale: CGFloat) {
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let path = NSBezierPath(ovalIn: rect)
    shadow(color: color("#41B6C8").withAlphaComponent(0.24), blur: 18 * scale, y: 0)
    color(fill).setFill()
    path.fill()
    NSShadow().set()
    stroke(path: path, color: strokeColor, width: 6 * scale)
}

func strokeLine(points: [NSPoint], color value: String, width: CGFloat, lineCap: NSBezierPath.LineCapStyle, lineJoin: NSBezierPath.LineJoinStyle) {
    guard let first = points.first else { return }
    let path = NSBezierPath()
    path.move(to: first)
    for point in points.dropFirst() {
        path.line(to: point)
    }
    stroke(path: path, color: value, width: width, lineCap: lineCap, lineJoin: lineJoin)
}

func stroke(path: NSBezierPath, color value: String, width: CGFloat, lineCap: NSBezierPath.LineCapStyle = .butt, lineJoin: NSBezierPath.LineJoinStyle = .miter) {
    color(value).setStroke()
    path.lineWidth = width
    path.lineCapStyle = lineCap
    path.lineJoinStyle = lineJoin
    path.stroke()
}

func gradientFill(path: NSBezierPath, start: String, end: String, angle: CGFloat) {
    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()
    NSGradient(starting: color(start), ending: color(end))?.draw(in: path.bounds, angle: angle)
    NSGraphicsContext.current?.restoreGraphicsState()
}

func shadow(color: NSColor, blur: CGFloat, y: CGFloat) {
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
}

func color(_ hex: String) -> NSColor {
    var value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var alpha: CGFloat = 1

    if value.count == 8, let alphaValue = Int(value.suffix(2), radix: 16) {
        alpha = CGFloat(alphaValue) / 255.0
        value = String(value.prefix(6))
    }

    guard value.count == 6, let integer = Int(value, radix: 16) else {
        return NSColor.white
    }

    return NSColor(
        calibratedRed: CGFloat((integer >> 16) & 0xff) / 255.0,
        green: CGFloat((integer >> 8) & 0xff) / 255.0,
        blue: CGFloat(integer & 0xff) / 255.0,
        alpha: alpha
    )
}
