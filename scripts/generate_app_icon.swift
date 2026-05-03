import AppKit
import Foundation

struct IconSize {
    let fileName: String
    let pixels: Int
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsDirectory = root.appendingPathComponent("assets", isDirectory: true)
let iconsetDirectory = assetsDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = assetsDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
if FileManager.default.fileExists(atPath: iconsetDirectory.path) {
    try FileManager.default.removeItem(at: iconsetDirectory)
}
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

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

for size in iconsetSizes {
    try writeIcon(size: size.pixels, to: iconsetDirectory.appendingPathComponent(size.fileName))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "HopdeckIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
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

    let baseRect = NSRect(x: 46 * scale, y: 46 * scale, width: 932 * scale, height: 932 * scale)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 216 * scale, yRadius: 216 * scale)
    shadow(color: NSColor.black.withAlphaComponent(0.30), blur: 36 * scale, y: -18 * scale)
    gradientFill(path: basePath, start: "#11283D", end: "#071319", angle: 88)
    NSShadow().set()

    let horizon = NSBezierPath(ovalIn: NSRect(x: -50 * scale, y: 584 * scale, width: 980 * scale, height: 280 * scale))
    gradientFill(path: horizon, start: "#64D2FF44", end: "#64D2FF00", angle: 25)

    let ember = NSBezierPath(ovalIn: NSRect(x: 398 * scale, y: 118 * scale, width: 520 * scale, height: 280 * scale))
    gradientFill(path: ember, start: "#E5C15D33", end: "#E5C15D00", angle: 15)

    drawDeckLayer(
        rect: NSRect(x: 222 * scale, y: 258 * scale, width: 580 * scale, height: 430 * scale),
        radius: 78 * scale,
        offset: NSPoint(x: -72 * scale, y: -54 * scale),
        alpha: 0.26,
        scale: scale
    )
    drawDeckLayer(
        rect: NSRect(x: 222 * scale, y: 258 * scale, width: 580 * scale, height: 430 * scale),
        radius: 78 * scale,
        offset: NSPoint(x: -34 * scale, y: -24 * scale),
        alpha: 0.42,
        scale: scale
    )

    let terminalRect = NSRect(x: 222 * scale, y: 270 * scale, width: 580 * scale, height: 430 * scale)
    let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 78 * scale, yRadius: 78 * scale)
    shadow(color: NSColor.black.withAlphaComponent(0.34), blur: 28 * scale, y: -12 * scale)
    gradientFill(path: terminalPath, start: "#193247", end: "#08141C", angle: 90)
    NSShadow().set()
    stroke(path: terminalPath, color: "#64D2FF66", width: 4 * scale)

    drawWindowControls(origin: NSPoint(x: 306 * scale, y: 624 * scale), scale: scale)
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
    color("#64D2FF").withAlphaComponent(alpha).setFill()
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
            NSPoint(x: 324 * scale, y: 482 * scale),
            NSPoint(x: 398 * scale, y: 524 * scale),
            NSPoint(x: 324 * scale, y: 566 * scale),
        ],
        color: "#F3F7FB",
        width: 28 * scale,
        lineCap: .round,
        lineJoin: .round
    )

    strokeLine(
        points: [
            NSPoint(x: 456 * scale, y: 472 * scale),
            NSPoint(x: 596 * scale, y: 472 * scale),
        ],
        color: "#64D2FF",
        width: 28 * scale,
        lineCap: .round,
        lineJoin: .round
    )
}

func drawHopRoute(scale: CGFloat) {
    let route = NSBezierPath()
    route.move(to: NSPoint(x: 392 * scale, y: 384 * scale))
    route.curve(
        to: NSPoint(x: 704 * scale, y: 556 * scale),
        controlPoint1: NSPoint(x: 492 * scale, y: 326 * scale),
        controlPoint2: NSPoint(x: 642 * scale, y: 388 * scale)
    )
    stroke(path: route, color: "#E5C15D", width: 20 * scale, lineCap: .round, lineJoin: .round)

    drawNode(center: NSPoint(x: 388 * scale, y: 386 * scale), radius: 34 * scale, fill: "#64D2FF", strokeColor: "#E7FBFF", scale: scale)
    drawNode(center: NSPoint(x: 550 * scale, y: 416 * scale), radius: 24 * scale, fill: "#071319", strokeColor: "#E5C15D", scale: scale)
    drawNode(center: NSPoint(x: 718 * scale, y: 562 * scale), radius: 43 * scale, fill: "#E5C15D", strokeColor: "#FFF4C7", scale: scale)
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
