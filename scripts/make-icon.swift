import AppKit

// Draws the app icon: a crop of three photo tiles, the middle one fully in frame with a heart,
// the outer two cut by the icon edge and faded.
// Usage: swift scripts/make-icon.swift Keepset/Assets.xcassets/AppIcon.appiconset

let canvas: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha
        ]
    )!
}

func gradient(_ top: UInt32, _ bottom: UInt32) -> CGGradient {
    CGGradient(colorsSpace: space, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func heartPath(width: CGFloat, center: CGPoint) -> CGPath {
    let scale = width / 32
    let path = CGMutablePath()
    for step in 0...200 {
        let t = Double(step) / 200 * 2 * .pi
        let x = 16 * pow(sin(t), 3)
        let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t) + 2.5
        let point = CGPoint(x: center.x + CGFloat(x) * scale, y: center.y + CGFloat(y) * scale)
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func fill(_ ctx: CGContext, _ path: CGPath, with gradient: CGGradient, in rect: CGRect) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY),
        options: []
    )
    ctx.restoreGState()
}

func draw(_ ctx: CGContext) {
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let plateShape = roundedRect(plate, radius: 186)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, 0.45))
    ctx.addPath(plateShape)
    ctx.setFillColor(color(0x1A1B1E))
    ctx.fillPath()
    ctx.restoreGState()
    fill(ctx, plateShape, with: gradient(0x35373C, 0x151618), in: plate)

    ctx.saveGState()
    ctx.addPath(plateShape)
    ctx.clip()

    let tile: CGFloat = 384
    let gap: CGFloat = 48
    let radius: CGFloat = 90
    let middle = CGRect(x: (canvas - tile) / 2, y: (canvas - tile) / 2, width: tile, height: tile)
    for dx in [-(tile + gap), tile + gap] {
        let side = middle.offsetBy(dx: dx, dy: 0)
        ctx.addPath(roundedRect(side, radius: radius))
        ctx.setFillColor(color(0xFFFFFF, 0.13))
        ctx.fillPath()
    }

    let middleShape = roundedRect(middle, radius: radius)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 34, color: color(0x000000, 0.5))
    ctx.addPath(middleShape)
    ctx.setFillColor(color(0xF2F2F4))
    ctx.fillPath()
    ctx.restoreGState()
    fill(ctx, middleShape, with: gradient(0xFFFFFF, 0xDCDDE2), in: middle)

    ctx.addPath(heartPath(width: 210, center: CGPoint(x: middle.midX, y: middle.midY)))
    ctx.setFillColor(color(0x1A1B1E))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(roundedRect(plate.insetBy(dx: 1.5, dy: 1.5), radius: 184.5))
    ctx.setStrokeColor(color(0xFFFFFF, 0.1))
    ctx.setLineWidth(3)
    ctx.strokePath()
}

func png(pixels: Int) -> Data {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let files: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

guard CommandLine.arguments.count == 2 else {
    print("usage: swift make-icon.swift <AppIcon.appiconset>")
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for (name, pixels) in files {
    try png(pixels: pixels).write(to: output.appendingPathComponent(name))
}
print("wrote \(files.count) icons to \(output.path)")
