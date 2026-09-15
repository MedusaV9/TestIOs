// Renders the SoooDreamy app icon (1024x1024 PNG) purely from code so no
// binary assets need to live in the repo. Runs on macOS (CI) via:
//   swift ios/scripts/GenerateIcon.swift <output.png> [variant]
//
// v3.0: `variant` selects one of the alternate-icon palettes (icon gifts —
// Agent C). Omitted/unknown variants render the classic 2.0 icon so the
// original CI invocation keeps producing the identical primary icon.
//
// 2.0 "Liquid Glass" icon — layered like the app's design system:
//   1. deep night gradient + drifting aurora blobs
//   2. fine particles (stars, bokeh dust, sparkles)
//   3. back glow
//   4. GLASS heart: translucent pane, refraction gradient, inner rim light,
//      specular top-lobe highlights, caustic bottom light
//   5. small companion glass heart
//   6. global gloss sweep across the pane
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: GenerateIcon.swift <output.png> [variant]\n".data(using: .utf8)!)
    exit(1)
}
let outURL = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// MARK: Variant palettes (v3.0 icon gifts)

typealias RGB = (r: CGFloat, g: CGFloat, b: CGFloat)

/// Everything that differs between icon variants — the geometry, particles
/// and glass shading stay identical so the family reads as one set.
struct Palette {
    let bg: [RGB]        // 3 background gradient stops (bottom → top-right)
    let aurora: [RGB]    // 3 aurora blob colors
    let glow: RGB        // back glow behind the heart
    let pane: [RGB]      // 3 glass pane gradient stops
    let caustic: RGB     // light pooling at the heart's bottom tip
    let rim: RGB         // colored third stop of the rim light
}

let palettes: [String: Palette] = [
    "classic": Palette(
        bg: [(0.055, 0.015, 0.13), (0.13, 0.045, 0.27), (0.30, 0.09, 0.40)],
        aurora: [(1.0, 0.36, 0.54), (0.66, 0.33, 0.97), (0.39, 0.40, 0.95)],
        glow: (1.0, 0.36, 0.54),
        pane: [(1.0, 0.62, 0.75), (1.0, 0.33, 0.55), (0.62, 0.27, 0.86)],
        caustic: (1.0, 0.72, 0.85), rim: (1.0, 0.55, 0.85)),
    "sunset": Palette(
        bg: [(0.14, 0.03, 0.10), (0.35, 0.08, 0.14), (0.65, 0.22, 0.13)],
        aurora: [(1.0, 0.55, 0.25), (1.0, 0.35, 0.45), (1.0, 0.75, 0.30)],
        glow: (1.0, 0.45, 0.30),
        pane: [(1.0, 0.75, 0.55), (1.0, 0.45, 0.35), (0.85, 0.25, 0.45)],
        caustic: (1.0, 0.80, 0.60), rim: (1.0, 0.60, 0.40)),
    "midnight": Palette(
        bg: [(0.01, 0.01, 0.05), (0.03, 0.05, 0.14), (0.07, 0.10, 0.25)],
        aurora: [(0.20, 0.35, 0.85), (0.35, 0.25, 0.75), (0.10, 0.55, 0.85)],
        glow: (0.45, 0.65, 1.0),
        pane: [(0.70, 0.82, 1.0), (0.42, 0.55, 0.95), (0.30, 0.35, 0.80)],
        caustic: (0.75, 0.85, 1.0), rim: (0.55, 0.70, 1.0)),
    "mint": Palette(
        bg: [(0.01, 0.10, 0.10), (0.02, 0.20, 0.19), (0.05, 0.33, 0.28)],
        aurora: [(0.25, 0.90, 0.70), (0.15, 0.70, 0.75), (0.55, 0.95, 0.65)],
        glow: (0.35, 0.95, 0.75),
        pane: [(0.75, 1.0, 0.90), (0.35, 0.90, 0.72), (0.15, 0.60, 0.60)],
        caustic: (0.80, 1.0, 0.92), rim: (0.55, 0.95, 0.80)),
    "rose": Palette(
        bg: [(0.16, 0.05, 0.09), (0.30, 0.09, 0.16), (0.48, 0.16, 0.25)],
        aurora: [(1.0, 0.45, 0.60), (0.95, 0.60, 0.70), (0.85, 0.30, 0.50)],
        glow: (1.0, 0.50, 0.62),
        pane: [(1.0, 0.80, 0.86), (1.0, 0.50, 0.64), (0.80, 0.30, 0.52)],
        caustic: (1.0, 0.85, 0.90), rim: (1.0, 0.62, 0.75)),
    "ocean": Palette(
        bg: [(0.01, 0.04, 0.12), (0.02, 0.10, 0.24), (0.03, 0.20, 0.38)],
        aurora: [(0.10, 0.55, 0.85), (0.20, 0.75, 0.85), (0.25, 0.40, 0.90)],
        glow: (0.25, 0.70, 0.95),
        pane: [(0.65, 0.90, 1.0), (0.30, 0.70, 0.95), (0.20, 0.45, 0.85)],
        caustic: (0.70, 0.92, 1.0), rim: (0.45, 0.80, 1.0)),
    "gold": Palette(
        bg: [(0.10, 0.05, 0.02), (0.22, 0.12, 0.04), (0.40, 0.24, 0.08)],
        aurora: [(1.0, 0.75, 0.30), (1.0, 0.55, 0.20), (0.95, 0.85, 0.45)],
        glow: (1.0, 0.78, 0.35),
        pane: [(1.0, 0.90, 0.65), (1.0, 0.72, 0.35), (0.85, 0.55, 0.20)],
        caustic: (1.0, 0.92, 0.70), rim: (1.0, 0.80, 0.45)),
    "lavender": Palette(
        bg: [(0.08, 0.06, 0.14), (0.16, 0.12, 0.28), (0.28, 0.22, 0.44)],
        aurora: [(0.70, 0.55, 0.95), (0.55, 0.45, 0.90), (0.85, 0.70, 1.0)],
        glow: (0.72, 0.58, 0.98),
        pane: [(0.90, 0.82, 1.0), (0.72, 0.55, 0.95), (0.50, 0.40, 0.85)],
        caustic: (0.92, 0.86, 1.0), rim: (0.78, 0.65, 1.0)),
    "blossom": Palette(
        bg: [(0.12, 0.02, 0.10), (0.24, 0.05, 0.20), (0.42, 0.12, 0.30)],
        aurora: [(1.0, 0.60, 0.80), (0.95, 0.40, 0.65), (1.0, 0.80, 0.88)],
        glow: (1.0, 0.55, 0.75),
        pane: [(1.0, 0.85, 0.92), (1.0, 0.55, 0.75), (0.75, 0.30, 0.60)],
        caustic: (1.0, 0.88, 0.94), rim: (1.0, 0.68, 0.85)),
]

let variantName = args.count >= 3 ? args[2] : "classic"
let pal = palettes[variantName] ?? palettes["classic"]!

func color(_ rgb: RGB, _ a: CGFloat = 1) -> CGColor {
    rgba(rgb.r, rgb.g, rgb.b, a)
}

// Deterministic PRNG so every CI run renders the identical icon.
var seed: UInt64 = 0x5EED_50DE
func rnd() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
}

// MARK: Layer 1 — night gradient + aurora blobs

let bg = CGGradient(colorsSpace: cs,
                    colors: [color(pal.bg[0]), color(pal.bg[1]),
                             color(pal.bg[2])] as CFArray,
                    locations: [0.0, 0.55, 1.0])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(size)),
                       end: CGPoint(x: CGFloat(size), y: 0), options: [])

/// Soft radial aurora blob fading to clear — the "liquid" behind the glass.
func auroraBlob(center: CGPoint, radius: CGFloat, color: CGColor) {
    let grad = CGGradient(colorsSpace: cs,
                          colors: [color, color.copy(alpha: 0)!] as CFArray,
                          locations: [0.0, 1.0])!
    ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius, options: [])
}
auroraBlob(center: CGPoint(x: 180, y: 880), radius: 500, color: color(pal.aurora[0], 0.30))
auroraBlob(center: CGPoint(x: 900, y: 640), radius: 560, color: color(pal.aurora[1], 0.28))
auroraBlob(center: CGPoint(x: 430, y: 90), radius: 560, color: color(pal.aurora[2], 0.26))

// MARK: Layer 2 — particles

// Star scatter.
for _ in 0..<80 {
    let x = rnd() * 1024, y = rnd() * 1024
    let r = 1.0 + rnd() * 3.0
    let a = 0.20 + rnd() * 0.6
    ctx.setFillColor(rgba(1, 1, 1, a))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}
// Bokeh dust — bigger, very faint discs floating in the liquid.
for _ in 0..<14 {
    let x = rnd() * 1024, y = rnd() * 1024
    let r = 10 + rnd() * 26
    ctx.setFillColor(rgba(1, 1, 1, 0.03 + rnd() * 0.05))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}
// Sparkles (4-point stars).
func sparkle(x: CGFloat, y: CGFloat, r: CGFloat, alpha: CGFloat) {
    ctx.setFillColor(rgba(1, 1, 1, alpha))
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x, y: y + r))
    p.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + r * 0.12, y: y + r * 0.12))
    p.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x + r * 0.12, y: y - r * 0.12))
    p.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x - r * 0.12, y: y - r * 0.12))
    p.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x - r * 0.12, y: y + r * 0.12))
    ctx.addPath(p)
    ctx.fillPath()
}
for _ in 0..<7 {
    sparkle(x: 80 + rnd() * 864, y: 80 + rnd() * 864, r: 9 + rnd() * 20, alpha: 0.55 + rnd() * 0.35)
}

// MARK: Heart geometry

// Parametric heart: x = 16sin^3 t, y = 13cos t - 5cos 2t - 2cos 3t - cos 4t  (y-up, matches CG).
func heartPath(center: CGPoint, scale: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let steps = 240
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let x = 16 * pow(sin(t), 3)
        let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
        let pt = CGPoint(x: center.x + x * scale, y: center.y + y * scale)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

let heartCenter = CGPoint(x: 512, y: 500)
let heart = heartPath(center: heartCenter, scale: 21)

// MARK: Layer 3 — back glow

let glow = CGGradient(colorsSpace: cs,
                      colors: [color(pal.glow, 0.50), color(pal.glow, 0.0)] as CFArray,
                      locations: [0.0, 1.0])!
ctx.drawRadialGradient(glow, startCenter: heartCenter, startRadius: 0,
                       endCenter: heartCenter, endRadius: 520, options: [])

// MARK: Layer 4 — the glass heart

/// Renders a full glass heart (pane, refraction, rim, speculars) at `path`.
/// `strength` scales all alphas so the companion heart reads lighter.
func drawGlassHeart(_ path: CGPath, bounds: CGRect, strength: CGFloat) {
    // 4a. Drop shadow lifting the pane off the background.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 70,
                  color: rgba(0.05, 0.0, 0.12, 0.55 * strength))
    // Shadow-caster fill: classic uses its historical tone so the primary
    // icon stays pixel-identical; variants derive it from their pane color.
    let shadowFill: RGB = variantName == "classic" || palettes[variantName] == nil
        ? (1.0, 0.45, 0.62)
        : (min(1, pal.pane[1].r + 0.1), min(1, pal.pane[1].g + 0.1), min(1, pal.pane[1].b + 0.08))
    ctx.setFillColor(color(shadowFill, 0.36 * strength))
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // 4b. Translucent pane: pink → violet, deliberately see-through so the
    // aurora + stars shimmer through the glass.
    let pane = CGGradient(colorsSpace: cs,
                          colors: [color(pal.pane[0], 0.62 * strength),
                                   color(pal.pane[1], 0.55 * strength),
                                   color(pal.pane[2], 0.62 * strength)] as CFArray,
                          locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(pane,
                           start: CGPoint(x: bounds.minX, y: bounds.maxY),
                           end: CGPoint(x: bounds.maxX, y: bounds.minY), options: [])

    // 4c. Refraction band: light bending through the pane — a bright diagonal
    // streak with a violet counter-streak below it.
    let refraction = CGGradient(colorsSpace: cs,
                                colors: [rgba(1, 1, 1, 0.0),
                                         rgba(1, 1, 1, 0.34 * strength),
                                         rgba(1, 1, 1, 0.0),
                                         rgba(0.55, 0.30, 0.95, 0.22 * strength),
                                         rgba(0.55, 0.30, 0.95, 0.0)] as CFArray,
                                locations: [0.30, 0.44, 0.58, 0.70, 0.85])!
    ctx.drawLinearGradient(refraction,
                           start: CGPoint(x: bounds.minX, y: bounds.minY),
                           end: CGPoint(x: bounds.maxX, y: bounds.maxY), options: [])

    // 4d. Caustic: light pooling at the bottom tip of the glass.
    let caustic = CGGradient(colorsSpace: cs,
                             colors: [color(pal.caustic, 0.42 * strength),
                                      color(pal.caustic, 0.0)] as CFArray,
                             locations: [0.0, 1.0])!
    ctx.drawRadialGradient(caustic,
                           startCenter: CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.10),
                           startRadius: 0,
                           endCenter: CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.10),
                           endRadius: bounds.width * 0.32, options: [])

    // 4e. Specular highlight: glossy ellipse on the upper-left lobe.
    ctx.saveGState()
    ctx.translateBy(x: bounds.midX - bounds.width * 0.20, y: bounds.midY + bounds.height * 0.26)
    ctx.rotate(by: -0.42)
    let specular = CGGradient(colorsSpace: cs,
                              colors: [rgba(1, 1, 1, 0.75 * strength), rgba(1, 1, 1, 0.0)] as CFArray,
                              locations: [0.0, 1.0])!
    ctx.scaleBy(x: 1.0, y: 0.52)   // squash the radial into an ellipse
    ctx.drawRadialGradient(specular, startCenter: .zero, startRadius: 0,
                           endCenter: .zero, endRadius: bounds.width * 0.24, options: [])
    ctx.restoreGState()

    // 4f. Tiny secondary glint on the right lobe.
    ctx.saveGState()
    ctx.translateBy(x: bounds.midX + bounds.width * 0.22, y: bounds.midY + bounds.height * 0.30)
    ctx.scaleBy(x: 1.0, y: 0.6)
    let glint = CGGradient(colorsSpace: cs,
                           colors: [rgba(1, 1, 1, 0.38 * strength), rgba(1, 1, 1, 0.0)] as CFArray,
                           locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glint, startCenter: .zero, startRadius: 0,
                           endCenter: .zero, endRadius: bounds.width * 0.10, options: [])
    ctx.restoreGState()

    ctx.restoreGState()   // un-clip heart

    // 4g. Rim light: gradient stroked edge — bright top-left, faint elsewhere,
    // like light catching the polished edge of the pane.
    let rim = path.copy(strokingWithWidth: bounds.width * 0.022,
                        lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addPath(rim)
    ctx.clip()
    let rimGrad = CGGradient(colorsSpace: cs,
                             colors: [rgba(1, 1, 1, 0.85 * strength),
                                      rgba(1, 1, 1, 0.18 * strength),
                                      color(pal.rim, 0.30 * strength)] as CFArray,
                             locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(rimGrad,
                           start: CGPoint(x: bounds.minX, y: bounds.maxY),
                           end: CGPoint(x: bounds.maxX, y: bounds.minY), options: [])
    ctx.restoreGState()

    // 4h. Inner edge glow just inside the rim (glass thickness).
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.setStrokeColor(rgba(1, 1, 1, 0.10 * strength))
    ctx.setLineWidth(bounds.width * 0.05)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()
}

let heartBounds = heart.boundingBox
drawGlassHeart(heart, bounds: heartBounds, strength: 1.0)

// MARK: Layer 5 — companion glass heart (smaller, rotated)

ctx.saveGState()
ctx.translateBy(x: 706, y: 736)
ctx.rotate(by: 0.30)
let small = heartPath(center: .zero, scale: 6.6)
drawGlassHeart(small, bounds: small.boundingBox, strength: 0.85)
ctx.restoreGState()

// MARK: Layer 6 — global gloss sweep

// One wide, very soft diagonal sheen across the whole icon — ties the
// layers together like a single pane of cover glass.
ctx.saveGState()
let sweep = CGGradient(colorsSpace: cs,
                       colors: [rgba(1, 1, 1, 0.0), rgba(1, 1, 1, 0.07),
                                rgba(1, 1, 1, 0.0)] as CFArray,
                       locations: [0.42, 0.56, 0.70])!
ctx.drawLinearGradient(sweep, start: CGPoint(x: 0, y: 0),
                       end: CGPoint(x: CGFloat(size), y: CGFloat(size)), options: [])
ctx.restoreGState()

// MARK: Write PNG

let img = ctx.makeImage()!
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write("cannot create png destination\n".data(using: .utf8)!)
    exit(1)
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("png finalize failed\n".data(using: .utf8)!)
    exit(1)
}
print("icon written to \(outURL.path)")
