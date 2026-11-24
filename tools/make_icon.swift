// Build Resources/AppIcon.icns from a pixel-art PNG.
//
//   swift tools/make_icon.swift Resources/AppIcon-source.png Resources/AppIcon.icns [style]
//
// The art is drawn on a macOS-style rounded-square tile. Large sizes use whole-number
// nearest-neighbour scaling so the pixels stay crisp; 16/32 px are smoothed.
// `style` picks the tile colour: ice (default), slate or sand.
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
  print("usage: swift tools/make_icon.swift <source.png> <out.icns> [ice|slate|sand]")
  exit(2)
}
let style = args.count > 3 ? args[3] : "ice"
let colors: [String: (NSColor, NSColor)] = [
  "slate": (NSColor(srgbRed: 0.27, green: 0.31, blue: 0.38, alpha: 1), NSColor(srgbRed: 0.10, green: 0.12, blue: 0.16, alpha: 1)),
  "ice": (NSColor(srgbRed: 0.93, green: 0.96, blue: 0.99, alpha: 1), NSColor(srgbRed: 0.70, green: 0.80, blue: 0.90, alpha: 1)),
  "sand": (NSColor(srgbRed: 0.93, green: 0.86, blue: 0.70, alpha: 1), NSColor(srgbRed: 0.72, green: 0.58, blue: 0.40, alpha: 1)),
]
guard let (top, bottom) = colors[style] else { print("unknown style \(style)"); exit(2) }

// Load the source and reduce it to its native pixel grid (the file may be pre-scaled).
let srcRep = NSBitmapImageRep(data: NSImage(contentsOfFile: args[1])!.tiffRepresentation!)!
func same(_ a: NSColor?, _ b: NSColor?) -> Bool { a == b }
var block = 1
for b in [8, 6, 5, 4, 3, 2] where srcRep.pixelsWide % b == 0 && srcRep.pixelsHigh % b == 0 {
  var ok = true
  outer: for y in 0..<srcRep.pixelsHigh {
    for x in 0..<srcRep.pixelsWide where !same(srcRep.colorAt(x: x, y: y), srcRep.colorAt(x: x - x % b, y: y - y % b)) {
      ok = false; break outer
    }
  }
  if ok { block = b; break }
}
let nw = srcRep.pixelsWide / block, nh = srcRep.pixelsHigh / block
let native = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: nw, pixelsHigh: nh, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
for y in 0..<nh { for x in 0..<nw { native.setColor(srcRep.colorAt(x: x * block, y: y * block)!, atX: x, y: y) } }
let art = native.cgImage!

/// Render one icon size. `size` is in pixels.
func render(_ size: Int) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  let ctx = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = ctx
  let s = CGFloat(size) / 1024
  // Apple's macOS icon grid: 824 px tile, 100 px margin, ~185 px corner radius at 1024.
  let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
  let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
  shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
  shadow.shadowBlurRadius = 24 * s
  shadow.set()
  NSGradient(starting: top, ending: bottom)!.draw(in: path, angle: -90)
  NSGraphicsContext.restoreGraphicsState()

  // Art: 16 px per native pixel at 1024 (so 8/4/2/1 at 512/256/128/64), centred on the tile.
  let artPx = CGFloat(nw) * 16 * s
  let rect = NSRect(x: (CGFloat(size) - artPx) / 2, y: (CGFloat(size) - artPx) / 2, width: artPx, height: artPx)
  ctx.cgContext.interpolationQuality = size >= 64 ? .none : .high
  ctx.cgContext.draw(art, in: rect.integral)
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

// Write an .iconset folder and convert it with iconutil.
let out = URL(fileURLWithPath: args[2])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
    try! render(pt * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
  }
}
// Also keep a 1024 px preview next to the .icns.
try! render(1024).representation(using: .png, properties: [:])!
  .write(to: out.deletingPathExtension().appendingPathExtension("png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard p.terminationStatus == 0 else { print("iconutil failed"); exit(1) }
print("wrote \(out.path) (art \(nw)x\(nh), source scale \(block)x, style \(style))")
