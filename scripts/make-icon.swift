#!/usr/bin/env swift
// Draws the Pomodoro app icon and writes Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift
//
// A tomato on a rounded-square field, with a clock hand sweep cut into it —
// drawn in code so the icon is reproducible and needs no binary source art.

import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    let s = size / 1024  // all geometry is authored at 1024pt

    // Rounded-square background: dark slate, so the red fruit reads at small sizes.
    let plate = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                             xRadius: 225 * s, yRadius: 225 * s)
    plate.addClip()
    let backdrop = NSGradient(colors: [
        NSColor(calibratedRed: 0.24, green: 0.25, blue: 0.31, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.13, alpha: 1),
    ])
    backdrop?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

    // Radial warmth behind the fruit — no hard edges.
    let warmth = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.35, alpha: 0.22),
        NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.35, alpha: 0.0),
    ])
    warmth?.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                 relativeCenterPosition: NSPoint(x: 0, y: 0.1))

    // The tomato body.
    let bodyRect = NSRect(x: 176 * s, y: 150 * s, width: 672 * s, height: 620 * s)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18 * s), blur: 40 * s,
                      color: NSColor(white: 0, alpha: 0.28).cgColor)
    let body = NSBezierPath(ovalIn: bodyRect)
    let flesh = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.78, green: 0.09, blue: 0.13, alpha: 1),
    ])
    body.addClip()
    flesh?.draw(in: bodyRect, angle: -80)
    context.restoreGState()

    // Glossy sheen on the upper left of the fruit.
    context.saveGState()
    let sheen = NSBezierPath(ovalIn: NSRect(x: 268 * s, y: 470 * s, width: 250 * s, height: 170 * s))
    NSColor(white: 1, alpha: 0.22).setFill()
    sheen.fill()
    context.restoreGState()

    // A clock dial inset in the fruit: the one element that must survive 16pt.
    context.saveGState()
    let center = CGPoint(x: bodyRect.midX, y: bodyRect.midY - 10 * s)
    let dialRadius = 232 * s
    let dialRect = NSRect(x: center.x - dialRadius, y: center.y - dialRadius,
                          width: dialRadius * 2, height: dialRadius * 2)
    context.setShadow(offset: CGSize(width: 0, height: -8 * s), blur: 24 * s,
                      color: NSColor(white: 0, alpha: 0.35).cgColor)
    NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(ovalIn: dialRect).fill()
    context.restoreGState()

    // Elapsed wedge, in the tomato's own red.
    context.saveGState()
    let wedge = NSBezierPath()
    wedge.move(to: center)
    wedge.appendArc(withCenter: center, radius: dialRadius, startAngle: 90, endAngle: 0, clockwise: true)
    wedge.close()
    NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.24, alpha: 0.22).setFill()
    wedge.fill()

    // Hands, dark enough to hold up against the pale dial.
    let ink = NSColor(calibratedRed: 0.22, green: 0.10, blue: 0.11, alpha: 1)
    ink.setStroke()
    let hands = NSBezierPath()
    hands.lineWidth = 40 * s
    hands.lineCapStyle = .round
    hands.move(to: center)
    hands.line(to: CGPoint(x: center.x, y: center.y + 158 * s))
    hands.move(to: center)
    hands.line(to: CGPoint(x: center.x + 112 * s, y: center.y))
    hands.stroke()

    ink.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 30 * s, y: center.y - 30 * s,
                                width: 60 * s, height: 60 * s)).fill()
    context.restoreGState()

    // Leafy calyx.
    let green = NSGradient(colors: [
        NSColor(calibratedRed: 0.42, green: 0.78, blue: 0.35, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.51, blue: 0.22, alpha: 1),
    ])
    let leafAngles: [CGFloat] = [90, 150, 210, 270, 330, 30]
    for angle in leafAngles {
        context.saveGState()
        context.translateBy(x: bodyRect.midX, y: 735 * s)
        context.rotate(by: angle * .pi / 180)
        let leaf = NSBezierPath()
        leaf.move(to: .zero)
        leaf.curve(to: CGPoint(x: 0, y: 165 * s),
                   controlPoint1: CGPoint(x: 95 * s, y: 40 * s),
                   controlPoint2: CGPoint(x: 62 * s, y: 135 * s))
        leaf.curve(to: .zero,
                   controlPoint1: CGPoint(x: -62 * s, y: 135 * s),
                   controlPoint2: CGPoint(x: -95 * s, y: 40 * s))
        leaf.close()
        leaf.addClip()
        green?.draw(in: NSRect(x: -100 * s, y: 0, width: 200 * s, height: 175 * s), angle: 90)
        context.restoreGState()
    }

    // Stem.
    NSColor(calibratedRed: 0.30, green: 0.58, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: bodyRect.midX - 26 * s, y: 735 * s,
                                     width: 52 * s, height: 120 * s),
                 xRadius: 26 * s, yRadius: 26 * s).fill()

    return image
}

func png(_ image: NSImage, size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .calibratedRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.first!)
    .deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// iconutil expects this exact naming.
let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

var rendered: [Int: NSImage] = [:]
for size in sizes { rendered[size] = drawIcon(size: CGFloat(size)) }

for (name, size) in entries {
    let data = png(rendered[size] ?? drawIcon(size: CGFloat(size)), size: size)
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}

let icns = root.appendingPathComponent("Resources/AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }

print("Wrote \(icns.path)")
