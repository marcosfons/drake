#!/usr/bin/env swift
// Draws Drake's app icon and writes every size the AppIcon set needs.
//
//   swift tools/make-icon.swift Drake/Assets.xcassets/AppIcon.appiconset
//
// The drawing is in a 1024-unit, y-down canvas laid out on Apple's macOS icon
// grid: an 824pt continuous-corner body centred on the canvas, with room for
// the drop shadow underneath. The mark is symbolic rather than literal: an
// ember tile with speed lines behind it, sliding into a ring that breaks
// where the tile crosses it. Sizes of 32px and below drop the speed lines.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255,
        alpha,
    ])!
}

func white(_ alpha: CGFloat) -> CGColor { rgb(0xFFFFFF, alpha) }
func black(_ alpha: CGFloat) -> CGColor { rgb(0x000000, alpha) }

func gradient(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: space,
               colors: stops.map(\.0) as CFArray,
               locations: stops.map(\.1))!
}

/// A rounded rectangle whose corners are quarter superellipses, so curvature
/// eases into the straight edges the way Apple's continuous corners do.
/// `radius` is the equivalent circular radius; the corner itself spans
/// about 1.53 times that along each edge.
func squirclePoints(_ r: CGRect, radius: CGFloat, exponent n: CGFloat = 3.3) -> [CGPoint] {
    let a = min(radius * 1.528, min(r.width, r.height) / 2)
    let corners: [(CGPoint, CGFloat)] = [
        (CGPoint(x: r.maxX - a, y: r.minY + a), -.pi / 2), // top right
        (CGPoint(x: r.maxX - a, y: r.maxY - a), 0),        // bottom right
        (CGPoint(x: r.minX + a, y: r.maxY - a), .pi / 2),  // bottom left
        (CGPoint(x: r.minX + a, y: r.minY + a), .pi),      // top left
    ]
    // Start and end mid-way along the top edge, so a dash seam lands on a
    // straight run rather than in a corner.
    var points = [CGPoint(x: r.midX, y: r.minY)]
    let steps = 96
    for (centre, start) in corners {
        for i in 0...steps {
            let t = start + CGFloat(i) / CGFloat(steps) * .pi / 2
            let c = cos(t), s = sin(t)
            points.append(CGPoint(x: centre.x + a * copysign(pow(abs(c), 2 / n), c),
                                  y: centre.y + a * copysign(pow(abs(s), 2 / n), s)))
        }
    }
    points.append(points[0])
    return points
}

func squircle(_ r: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: squirclePoints(r, radius: radius))
    path.closeSubpath()
    return path
}

func draw(in ctx: CGContext, pixels: Int) {
    let s = CGFloat(pixels) / 1024
    let small = pixels <= 32
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: s, y: -s)
    // Shadow offsets and blur ignore the CTM, so they are given in pixels.
    func shadow(_ dy: CGFloat, _ blur: CGFloat, _ alpha: CGFloat) {
        ctx.setShadow(offset: CGSize(width: 0, height: -dy * s), blur: blur * s, color: black(alpha))
    }

    // Body
    let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let body = squircle(bodyRect, radius: 185)
    ctx.saveGState()
    shadow(10, 28, 0.45)
    ctx.addPath(body)
    ctx.setFillColor(rgb(0x000000))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(rgb(0x1C1C1F), 0), (rgb(0x09090A), 0.5), (rgb(0x000000), 1)]),
                           start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
    // Ember glow behind the sheet
    ctx.drawRadialGradient(gradient([(rgb(0xFF6A3D, 0.12), 0), (rgb(0xFF3B6B, 0.03), 0.5), (rgb(0xFF3B6B, 0), 1)]),
                           startCenter: CGPoint(x: 430, y: 430), startRadius: 0,
                           endCenter: CGPoint(x: 430, y: 430), endRadius: 560, options: [])
    // Cool counter-light from the drop zone
    ctx.drawRadialGradient(gradient([(rgb(0x5B7CFF, 0.05), 0), (rgb(0x5B7CFF, 0), 1)]),
                           startCenter: CGPoint(x: 740, y: 760), startRadius: 0,
                           endCenter: CGPoint(x: 740, y: 760), endRadius: 420, options: [])
    // Glass sheen on the upper half
    ctx.drawLinearGradient(gradient([(white(0.05), 0), (white(0), 1)]),
                           start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 520), options: [])
    ctx.restoreGState()

    // Hairline rim, brighter at the top
    ctx.saveGState()
    ctx.addPath(body)
    ctx.setLineWidth(small ? 0 : 4)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(gradient([(white(0.22), 0), (white(0.04), 0.5), (white(0.08), 1)]),
                           start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
    ctx.restoreGState()

    let item = CGRect(x: 280, y: 280, width: 280, height: 280)
    let itemRadius: CGFloat = 68
    let centre = CGPoint(x: item.midX, y: item.midY)

    // Target: a heavy ring, broken by a gap where the tile passes over it.
    let gap: CGFloat = small ? 34 : 26
    let target = squircle(CGRect(x: 440, y: 440, width: 360, height: 360), radius: 84)
    ctx.saveGState()
    ctx.addRect(bodyRect)
    ctx.addPath(squircle(item.insetBy(dx: -gap, dy: -gap), radius: itemRadius + gap))
    ctx.clip(using: .evenOdd)
    ctx.addPath(target)
    ctx.setFillColor(white(small ? 0.08 : 0.04))
    ctx.fillPath()
    ctx.addPath(target)
    ctx.setLineWidth(small ? 48 : 34)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(gradient([(white(0.46), 0), (white(0.16), 1)]),
                           start: CGPoint(x: 440, y: 440), end: CGPoint(x: 800, y: 800), options: [])
    ctx.restoreGState()

    // Speed lines trailing up and to the left, fading away from the tile.
    if !small {
        let back = CGPoint(x: -0.7071, y: -0.7071)
        let across = CGPoint(x: 0.7071, y: -0.7071)
        let lines: [(offset: CGFloat, from: CGFloat, to: CGFloat)] = [(-84, 150, 222), (0, 204, 318), (84, 150, 222)]
        for line in lines {
            func at(_ d: CGFloat) -> CGPoint {
                CGPoint(x: centre.x + back.x * d + across.x * line.offset,
                        y: centre.y + back.y * d + across.y * line.offset)
            }
            ctx.saveGState()
            ctx.move(to: at(line.from))
            ctx.addLine(to: at(line.to))
            ctx.setLineWidth(26)
            ctx.setLineCap(.round)
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            ctx.drawLinearGradient(gradient([(rgb(0xFF8A45, 0.95), 0), (rgb(0xFFB547, 0.15), 1)]),
                                   start: at(line.from - 13), end: at(line.to + 13), options: [])
            ctx.restoreGState()
        }
    }

    // Tile, lifted on its own ember glow
    let tile = squircle(item, radius: itemRadius)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20 * s), blur: 80 * s, color: rgb(0xFF4A50, 0.55))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0xFF6A3D))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(rgb(0xFFB547), 0), (rgb(0xFF6A3D), 0.5), (rgb(0xF0306A), 1)]),
                           start: CGPoint(x: item.minX, y: item.minY), end: CGPoint(x: item.maxX, y: item.maxY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.drawLinearGradient(gradient([(white(0.26), 0), (white(0), 1)]),
                           start: CGPoint(x: 0, y: item.minY), end: CGPoint(x: 0, y: item.midY), options: [])
    if !small {
        // Inner rim, brightest along the top edge
        ctx.addPath(tile)
        ctx.setLineWidth(8)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(gradient([(white(0.45), 0), (white(0.05), 1)]),
                               start: CGPoint(x: 0, y: item.minY), end: CGPoint(x: 0, y: item.maxY), options: [])
    }
    ctx.restoreGState()
}

func render(_ pixels: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    draw(in: ctx, pixels: pixels)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
}

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <AppIcon.appiconset>\n".data(using: .utf8)!)
    exit(2)
}
let dir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        render(size * scale, to: dir.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: dir.appendingPathComponent("Contents.json"))
print("wrote \(images.count) images to \(dir.path)")
