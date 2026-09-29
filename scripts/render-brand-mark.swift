import CoreGraphics
import CoreText
import Foundation
import ImageIO

// Renders the OpenCCman mark from `LaunchMark`, so the app icon and the launch
// screen cannot drift apart. Build it together with the mark:
//
//   xcrun swiftc OpenCCman/Model/LaunchMotion.swift scripts/render-brand-mark.swift -o render-brand-mark
//   ./render-brand-mark [--font <LXGWWenKai-Medium.ttf>] [--check]
//
// In the mark's 1024 pt design space it writes
// - AppIcon.icon/Assets/ring-blue.svg and ring-purple.svg: the two arcs;
// - AppIcon.icon/Assets/glyph-jian.svg and glyph-fan.svg: 简 and 繁 outlined from
//   LXGW WenKai Medium 1.520 (SIL Open Font License 1.1), only with --font;
// - the LaunchMark launch screen images, drawn like the first frame of the
//   launch transition: the same arcs and the LaunchGlyph template images.
// AppIcon.icon/icon.json (placement, glass, appearances) is edited by hand or in
// Icon Composer. --check writes nothing and fails when the ring layers or the
// icon's colours no longer match LaunchMark and the launch colour sets.

@main
enum RenderBrandMark {
  static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
  static let icon = root.appendingPathComponent("OpenCCman/AppIcon.icon")
  static let catalog = root.appendingPathComponent("OpenCCman/Assets.xcassets")

  static let arcs: [(layer: String, startAngle: Double, head: CGPoint, color: String)] = [
    ("ring-blue", -90, LaunchMark.blueHead, "LaunchRingBlue"),
    ("ring-purple", 90, LaunchMark.purpleHead, "LaunchRingPurple"),
  ]

  /// 简 and 繁 where the LaunchGlyph images have them: the 2.0 icon set both in
  /// LXGW WenKai Medium, which is this size and these baseline origins here.
  static let glyphSize: CGFloat = 321.875
  static let glyphs: [(layer: String, character: String, origin: CGPoint, image: String, box: CGRect)] = [
    ("glyph-jian", "简", CGPoint(x: 210.97, y: 496.55), "LaunchGlyphJian", LaunchMark.jian),
    ("glyph-fan", "繁", CGPoint(x: 491.88, y: 743.75), "LaunchGlyphFan", LaunchMark.fan),
  ]

  struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  struct RGB {
    var red, green, blue: Double

    var hex: String {
      String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    var cgColor: CGColor {
      CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [red, green, blue, 1])!
    }

    func matches(_ other: RGB) -> Bool {
      abs(red - other.red) < 0.0005 && abs(green - other.green) < 0.0005 && abs(blue - other.blue) < 0.0005
    }
  }

  static func main() {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      if arguments == ["--check"] {
        try check()
      } else if arguments.isEmpty {
        try render(font: nil)
      } else if arguments.count == 2, arguments[0] == "--font" {
        try render(font: arguments[1])
      } else {
        throw Failure("usage: render-brand-mark [--font <LXGWWenKai-Medium.ttf>] [--check]")
      }
    } catch {
      FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
      exit(1)
    }
  }

  // MARK: - Icon layers

  static func render(font path: String?) throws {
    let assets = icon.appendingPathComponent("Assets")
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    for arc in arcs {
      try ring(arc.startAngle, head: arc.head, color: colors(arc.color).light)
        .write(to: assets.appendingPathComponent("\(arc.layer).svg"), atomically: true, encoding: .utf8)
    }
    if let path {
      let font = try wenKai(at: path)
      let ink = try colors("LaunchInk").light
      for glyph in glyphs {
        try outline(glyph.character, origin: glyph.origin, font: font, color: ink)
          .write(to: assets.appendingPathComponent("\(glyph.layer).svg"), atomically: true, encoding: .utf8)
      }
      print("Outlined 简 and 繁 from \(CTFontCopyName(font, kCTFontVersionNameKey).map { $0 as String } ?? "an unknown version")")
    }
    try renderLaunchImages()
    print("Rendered the icon ring layers and the LaunchMark images")
  }

  static func svg(_ body: String) -> String {
    let side = number(LaunchMark.designSize)
    return """
      <svg xmlns="http://www.w3.org/2000/svg" width="\(side)" height="\(side)" viewBox="0 0 \(side) \(side)">
        \(body)
      </svg>

      """
  }

  /// One arc of the ring and its barb, outlined the way `LaunchMark.arrow` is
  /// stroked with round caps and joins: a band and a capsule. The system icon
  /// renderer (iOS 26.5) fills every path and closes open ones, so an SVG stroke
  /// shows up as a filled segment in dark and tinted icons.
  static func ring(_ startAngle: Double, head: CGPoint, color: RGB) -> String {
    precondition(LaunchMark.lineCap == .round && LaunchMark.lineJoin == .round, "Outline other caps and joins before changing them")
    let c = LaunchMark.center, r = LaunchMark.ringRadius, h = LaunchMark.lineWidth / 2
    func polar(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
      let a = degrees * .pi / 180
      return CGPoint(x: c.x + radius * CGFloat(cos(a)), y: c.y + radius * CGFloat(sin(a)))
    }
    func pt(_ p: CGPoint) -> String { "\(number(p.x)) \(number(p.y))" }
    /// Half a turn of radius h around `center`, from `from` to `to`, through `bulge`.
    func cap(_ from: CGPoint, _ to: CGPoint, around center: CGPoint, through bulge: CGPoint) -> String {
      let sweep = (from.x - center.x) * (bulge.y - center.y) - (from.y - center.y) * (bulge.x - center.x) > 0 ? 1 : 0
      return "A\(number(h)) \(number(h)) 0 0 \(sweep) \(pt(to))"
    }
    /// The point `distance` along the direction of travel (clockwise) from `degrees` on the ring; negative goes back.
    func ahead(_ degrees: Double, by distance: CGFloat) -> CGPoint {
      let a = degrees * .pi / 180, p = polar(degrees, r)
      return CGPoint(x: p.x - distance * CGFloat(sin(a)), y: p.y + distance * CGFloat(cos(a)))
    }
    let end = startAngle + 90, tip = polar(end, r)
    let band = "M\(pt(polar(startAngle, r + h)))A\(number(r + h)) \(number(r + h)) 0 0 1 \(pt(polar(end, r + h)))"
      + cap(polar(end, r + h), polar(end, r - h), around: tip, through: ahead(end, by: h))
      + "A\(number(r - h)) \(number(r - h)) 0 0 0 \(pt(polar(startAngle, r - h)))"
      + cap(polar(startAngle, r - h), polar(startAngle, r + h), around: polar(startAngle, r), through: ahead(startAngle, by: -h))
      + "Z"
    let length = hypot(head.x - tip.x, head.y - tip.y)
    let n = CGPoint(x: -(head.y - tip.y) / length * h, y: (head.x - tip.x) / length * h)
    let forward = CGPoint(x: (head.x - tip.x) / length * h, y: (head.y - tip.y) / length * h)
    let barb = "M\(pt(CGPoint(x: tip.x + n.x, y: tip.y + n.y)))L\(pt(CGPoint(x: head.x + n.x, y: head.y + n.y)))"
      + cap(CGPoint(x: head.x + n.x, y: head.y + n.y), CGPoint(x: head.x - n.x, y: head.y - n.y), around: head,
            through: CGPoint(x: head.x + forward.x, y: head.y + forward.y))
      + "L\(pt(CGPoint(x: tip.x - n.x, y: tip.y - n.y)))"
      + cap(CGPoint(x: tip.x - n.x, y: tip.y - n.y), CGPoint(x: tip.x + n.x, y: tip.y + n.y), around: tip,
            through: CGPoint(x: tip.x - forward.x, y: tip.y - forward.y))
      + "Z"
    // Separate paths, so the overlap stays filled whichever way each one winds.
    return svg("<path d=\"\(band)\" fill=\"\(color.hex)\"/>\n  <path d=\"\(barb)\" fill=\"\(color.hex)\"/>")
  }

  static func wenKai(at path: String) throws -> CTFont {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
          let descriptor = descriptors.first else { throw Failure("cannot read a font at \(url.path)") }
    let font = CTFontCreateWithFontDescriptor(descriptor, glyphSize, nil)
    let name = CTFontCopyPostScriptName(font) as String
    guard name == "LXGWWenKai-Medium" else { throw Failure("expected LXGW WenKai Medium, got \(name)") }
    return font
  }

  static func outline(_ character: String, origin: CGPoint, font: CTFont, color: RGB) throws -> String {
    var units = Array(character.utf16)
    var ids = [CGGlyph](repeating: 0, count: units.count)
    guard CTFontGetGlyphsForCharacters(font, &units, &ids, units.count),
          let path = CTFontCreatePathForGlyph(font, ids[0], nil) else { throw Failure("no outline for \(character)") }
    var d = ""
    path.applyWithBlock { element in
      let points = element.pointee.points
      func p(_ i: Int) -> String { "\(number(origin.x + points[i].x)) \(number(origin.y - points[i].y))" }
      switch element.pointee.type {
      case .moveToPoint: d += "M" + p(0)
      case .addLineToPoint: d += "L" + p(0)
      case .addQuadCurveToPoint: d += "Q" + p(0) + " " + p(1)
      case .addCurveToPoint: d += "C" + p(0) + " " + p(1) + " " + p(2)
      case .closeSubpath: d += "Z"
      @unknown default: break
      }
    }
    return svg("<path d=\"\(d)\" fill=\"\(color.hex)\"/>")
  }

  static func number(_ value: CGFloat) -> String {
    var text = String(format: "%.2f", Double(value))
    while text.hasSuffix("0") { text.removeLast() }
    if text.hasSuffix(".") { text.removeLast() }
    return text == "-0" ? "0" : text
  }

  // MARK: - Launch screen image

  /// Draws the mark like `LaunchTransitionView` does at rest, at every scale and appearance of the image set.
  static func renderLaunchImages() throws {
    let set = catalog.appendingPathComponent("LaunchMark.imageset")
    for entry in try images(in: set) {
      guard let file = entry["filename"] as? String else { continue }
      let scale = Int((entry["scale"] as? String ?? "1x").dropLast()) ?? 1
      let dark = (entry["appearances"] as? [[String: String]])?.contains { $0["value"] == "dark" } ?? false
      try launchImage(scale: scale, dark: dark).write(to: set.appendingPathComponent(file))
    }
  }

  static func launchImage(scale: Int, dark: Bool) throws -> Data {
    let side = Int(LaunchMark.size) * scale
    guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw Failure("cannot create a \(side) px canvas") }
    // Points with a top-left origin, as SwiftUI lays the mark out.
    context.translateBy(x: 0, y: CGFloat(side))
    context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    context.interpolationQuality = .high
    let k = LaunchMark.scale, middle = LaunchMark.size / 2
    func place(_ p: CGPoint) -> CGPoint {
      CGPoint(x: middle + (p.x - LaunchMark.center.x) * k, y: middle + (p.y - LaunchMark.center.y) * k)
    }
    for arc in arcs {
      let color = try colors(arc.color)
      context.addLines(between: LaunchMark.arrow(startAngle: arc.startAngle, head: arc.head, rotation: 0, growth: 1).map(place))
      context.setStrokeColor((dark ? color.dark : color.light).cgColor)
      context.setLineWidth(LaunchMark.lineWidth * k)
      context.setLineCap(LaunchMark.lineCap)
      context.setLineJoin(LaunchMark.lineJoin)
      context.strokePath()
    }
    let ink = try colors("LaunchInk")
    for glyph in glyphs {
      let rect = CGRect(origin: place(glyph.box.origin), size: CGSize(width: glyph.box.width * k, height: glyph.box.height * k))
      let mask = try templateImage(glyph.image)
      context.saveGState()
      context.beginTransparencyLayer(auxiliaryInfo: nil)
      context.saveGState()
      // CGImage draws bottom-up; flip it back within its rect.
      context.translateBy(x: 0, y: rect.minY + rect.maxY)
      context.scaleBy(x: 1, y: -1)
      context.draw(mask, in: rect)
      context.restoreGState()
      // Template rendering: the image's alpha, filled with the ink colour.
      context.setBlendMode(.sourceIn)
      context.setFillColor((dark ? ink.dark : ink.light).cgColor)
      context.fill(rect)
      context.endTransparencyLayer()
      context.restoreGState()
    }
    guard let image = context.makeImage() else { throw Failure("cannot finish the launch image") }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
      throw Failure("cannot encode PNG")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw Failure("cannot encode PNG") }
    return data as Data
  }

  static func templateImage(_ name: String) throws -> CGImage {
    let set = catalog.appendingPathComponent("\(name).imageset")
    guard let file = try images(in: set).compactMap({ $0["filename"] as? String }).first,
          let source = CGImageSourceCreateWithURL(set.appendingPathComponent(file) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw Failure("cannot read \(name)") }
    return image
  }

  // MARK: - Asset catalog

  static func images(in set: URL) throws -> [[String: Any]] {
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: set.appendingPathComponent("Contents.json")))
    guard let images = (object as? [String: Any])?["images"] as? [[String: Any]] else {
      throw Failure("\(set.lastPathComponent) lists no images")
    }
    return images
  }

  /// The light and dark values of a launch colour set.
  static func colors(_ name: String) throws -> (light: RGB, dark: RGB) {
    let url = catalog.appendingPathComponent("\(name).colorset/Contents.json")
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    guard let entries = (object as? [String: Any])?["colors"] as? [[String: Any]] else { throw Failure("\(name) has no colours") }
    var light: RGB?, dark: RGB?
    for entry in entries {
      guard let color = entry["color"] as? [String: Any], color["color-space"] as? String == "srgb",
            let c = color["components"] as? [String: String],
            let red = c["red"].flatMap(Double.init), let green = c["green"].flatMap(Double.init), let blue = c["blue"].flatMap(Double.init),
            [red, green, blue].allSatisfy({ (0 ... 1).contains($0) })
      else { throw Failure("\(name) needs sRGB components between 0 and 1") }
      let rgb = RGB(red: red, green: green, blue: blue)
      if (entry["appearances"] as? [[String: String]])?.contains(where: { $0["value"] == "dark" }) == true {
        dark = rgb
      } else {
        light = rgb
      }
    }
    guard let light, let dark else { throw Failure("\(name) needs a light and a dark value") }
    return (light, dark)
  }

  // MARK: - Check

  static func check() throws {
    let assets = icon.appendingPathComponent("Assets")
    var expectedDark: [String: RGB] = [:]
    for arc in arcs {
      let color = try colors(arc.color)
      let committed = try String(contentsOf: assets.appendingPathComponent("\(arc.layer).svg"), encoding: .utf8)
      guard committed == ring(arc.startAngle, head: arc.head, color: color.light) else {
        throw Failure("\(arc.layer).svg no longer matches LaunchMark; run scripts/render-brand-mark.swift")
      }
      expectedDark["\(arc.layer).svg"] = color.dark
    }
    let ink = try colors("LaunchInk")
    for glyph in glyphs {
      let committed = try String(contentsOf: assets.appendingPathComponent("\(glyph.layer).svg"), encoding: .utf8)
      guard committed.contains("fill=\"\(ink.light.hex)\"") else { throw Failure("\(glyph.layer).svg is not in the launch ink") }
      expectedDark["\(glyph.layer).svg"] = ink.dark
    }

    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: icon.appendingPathComponent("icon.json")))
    guard let groups = (object as? [String: Any])?["groups"] as? [[String: Any]] else { throw Failure("icon.json has no groups") }
    var found = Set<String>()
    for layer in groups.flatMap({ $0["layers"] as? [[String: Any]] ?? [] }) {
      guard let name = layer["image-name"] as? String,
            FileManager.default.fileExists(atPath: assets.appendingPathComponent(name).path)
      else { throw Failure("icon.json refers to a missing layer image") }
      guard let expected = expectedDark[name] else { continue }
      let specializations = layer["fill-specializations"] as? [[String: Any]] ?? []
      let value = specializations.first { $0["appearance"] as? String == "dark" }?["value"] as? [String: Any]
      guard let solid = value?["solid"] as? String, solid.hasPrefix("srgb:") else {
        throw Failure("\(name) needs a solid sRGB dark fill")
      }
      let c = solid.dropFirst(5).split(separator: ",").compactMap { Double($0) }
      guard c.count == 4, RGB(red: c[0], green: c[1], blue: c[2]).matches(expected) else {
        throw Failure("\(name)'s dark fill differs from its launch colour set")
      }
      found.insert(name)
    }
    guard found == Set(expectedDark.keys) else {
      throw Failure("icon.json is missing \(Set(expectedDark.keys).subtracting(found).sorted())")
    }
    print("PASS: app icon layers and dark colours match the launch mark")
  }
}
