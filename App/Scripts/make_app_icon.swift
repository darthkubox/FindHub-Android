// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// Regenerate from the App directory with:
// swift Scripts/make_app_icon.swift Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png
// The white canvas stays square and opaque; iOS supplies the outer icon mask.
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 255) / 255,
        CGFloat((hex >> 8) & 255) / 255,
        CGFloat(hex & 255) / 255, alpha
    ])!
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift make_app_icon.swift <output.png>")
}
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Cannot create icon canvas")
}
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)
ctx.setAllowsAntialiasing(true)
ctx.setFillColor(color(0xFFFFFF))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

func gradient(_ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: start, end: end,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func glow(_ hex: UInt32, alpha: CGFloat, at center: CGPoint, radius: CGFloat) {
    let gradient = CGGradient(colorsSpace: space,
                              colors: [color(hex, alpha), color(hex, alpha * 0.55), color(hex, 0)] as CFArray,
                              locations: [0, 0.4, 1])!
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius, options: [])
}

// A broad navigation arrow with rounded tips and a deep, recognisable notch.
// Two folded faces meet along the northeast diagonal, rather than colour bands.
let tip = CGPoint(x: 811, y: 211)
let fold = CGPoint(x: 459, y: 562)
let mark = CGMutablePath()
mark.move(to: CGPoint(x: 215, y: 435))
mark.addLine(to: CGPoint(x: 778, y: 196))
mark.addCurve(to: CGPoint(x: 827, y: 244),
              control1: CGPoint(x: 818, y: 179), control2: CGPoint(x: 845, y: 203))
mark.addLine(to: CGPoint(x: 590, y: 810))
mark.addCurve(to: CGPoint(x: 534, y: 810),
              control1: CGPoint(x: 578, y: 841), control2: CGPoint(x: 546, y: 841))
mark.addLine(to: CGPoint(x: 452, y: 582))
mark.addQuadCurve(to: CGPoint(x: 434, y: 563), control: CGPoint(x: 447, y: 568))
mark.addLine(to: CGPoint(x: 214, y: 488))
mark.addCurve(to: CGPoint(x: 215, y: 435),
              control1: CGPoint(x: 183, y: 477), control2: CGPoint(x: 183, y: 449))
mark.closeSubpath()

// A shallow translucent-looking rim and a restrained contact shadow.
ctx.saveGState()
ctx.translateBy(x: 0, y: 10)
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22,
              color: color(0x5E8CB5, 0.15))
ctx.addPath(mark)
ctx.setFillColor(color(0xB9E2F7))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(mark)
ctx.clip()

// Blue face: saturated Workspace blue, with cyan near the point and a lilac glow.
gradient([color(0x60DCF3), color(0x318BFF), color(0x2778F4)],
         from: CGPoint(x: 800, y: 220), to: CGPoint(x: 490, y: 790))
glow(0xBAA2FF, alpha: 0.88, at: CGPoint(x: 566, y: 794), radius: 205)
glow(0x98EFFF, alpha: 0.7, at: CGPoint(x: 710, y: 370), radius: 180)

// Upper face: green wing flowing into a warm yellow nose.
ctx.saveGState()
let upperFace = CGMutablePath()
upperFace.move(to: CGPoint(x: 120, y: 120))
upperFace.addLine(to: CGPoint(x: 900, y: 120))
upperFace.addLine(to: tip)
upperFace.addLine(to: fold)
upperFace.addLine(to: CGPoint(x: 120, y: 520))
upperFace.closeSubpath()
ctx.addPath(upperFace)
ctx.clip()
gradient([color(0x00AF63), color(0x05C86D), color(0xB5E94E), color(0xFFE000)],
         from: CGPoint(x: 280, y: 480), to: CGPoint(x: 790, y: 240))
glow(0x87EDDE, alpha: 0.9, at: CGPoint(x: 255, y: 436), radius: 225)
glow(0xFFF58E, alpha: 0.75, at: CGPoint(x: 768, y: 219), radius: 170)
ctx.restoreGState()

// Soft light along the fold gives both faces a polished, gently raised edge.
ctx.saveGState()
let foldLight = CGMutablePath()
foldLight.move(to: CGPoint(x: 451, y: 564))
foldLight.addLine(to: CGPoint(x: 811, y: 204))
foldLight.addLine(to: CGPoint(x: 805, y: 243))
foldLight.addLine(to: CGPoint(x: 472, y: 576))
foldLight.closeSubpath()
ctx.addPath(foldLight)
ctx.clip()
gradient([color(0xFFFFFF, 0.42), color(0xFFFFFF, 0)],
         from: CGPoint(x: 630, y: 388), to: CGPoint(x: 646, y: 404))
ctx.restoreGState()

// Inset edge glints, clipped to the mark so the silhouette remains crisp.
ctx.addPath(mark)
ctx.setStrokeColor(color(0xFFFFFF, 0.4))
ctx.setLineWidth(9)
ctx.strokePath()
ctx.addPath(mark)
ctx.setStrokeColor(color(0x2086AF, 0.12))
ctx.setLineWidth(2)
ctx.strokePath()
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("Cannot render icon") }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("Cannot open output: \(url.path)") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write PNG") }
print("Wrote opaque sRGB \(size)×\(size) icon: \(url.path)")
