// Original vector artwork rendered to the opaque iOS app icon.
// Run from the repository root: swift scripts/generate_icon.swift
import AppKit

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let bounds = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(starting: NSColor(srgbRed: 0.14, green: 0.29, blue: 0.23, alpha: 1),
           ending: NSColor(srgbRed: 0.29, green: 0.48, blue: 0.36, alpha: 1))!
    .draw(in: bounds, angle: 65)
let cream = NSColor(srgbRed: 0.97, green: 0.95, blue: 0.86, alpha: 1)
// Open pages, joined by a generous center gutter, with a growing leaf above.
cream.setFill()
let left = NSBezierPath()
left.move(to: NSPoint(x: 235, y: 660))
left.curve(to: NSPoint(x: 485, y: 610), controlPoint1: NSPoint(x: 330, y: 680), controlPoint2: NSPoint(x: 423, y: 645))
left.line(to: NSPoint(x: 485, y: 305))
left.curve(to: NSPoint(x: 235, y: 350), controlPoint1: NSPoint(x: 407, y: 348), controlPoint2: NSPoint(x: 324, y: 372))
left.close(); left.fill()
let right = NSBezierPath()
right.move(to: NSPoint(x: 539, y: 610))
right.curve(to: NSPoint(x: 789, y: 660), controlPoint1: NSPoint(x: 615, y: 645), controlPoint2: NSPoint(x: 705, y: 680))
right.line(to: NSPoint(x: 789, y: 350))
right.curve(to: NSPoint(x: 539, y: 305), controlPoint1: NSPoint(x: 700, y: 372), controlPoint2: NSPoint(x: 617, y: 348))
right.close(); right.fill()
NSColor(srgbRed: 0.76, green: 0.83, blue: 0.56, alpha: 1).setFill()
let leaf = NSBezierPath()
leaf.move(to: NSPoint(x: 512, y: 670))
leaf.curve(to: NSPoint(x: 650, y: 817), controlPoint1: NSPoint(x: 483, y: 761), controlPoint2: NSPoint(x: 559, y: 819))
leaf.curve(to: NSPoint(x: 512, y: 670), controlPoint1: NSPoint(x: 665, y: 724), controlPoint2: NSPoint(x: 601, y: 675))
leaf.close(); leaf.fill()
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: "app/assets.xcassets/app-icon.appiconset/app-icon.png")
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print("Generated \(output.path)")
