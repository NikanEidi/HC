//
//  GlassmorphismBG.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  MIDNIGHT FORGE — Visual Foundation Layer                     ║
//  ║                                                               ║
//  ║  This file defines the entire color system ("Forge" palette)  ║
//  ║  and the multi-layered background composition:                ║
//  ║    L0: Obsidian void                                          ║
//  ║    L1: Retro-futuristic perspective grid                      ║
//  ║    L2: Three breathing aurora orbs                            ║
//  ║    L3: Detailed ASCII dragon watermark                        ║
//  ║    L4: CRT phosphor scanlines + sweep beam                    ║
//  ║    L5: Cinematic vignette                                     ║
//  ║                                                               ║
//  ║  Also provides the reusable GlassCard ViewModifier.           ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Forge Design System (Color Palette)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Centralized color palette for the "Midnight Forge" design system.
/// Every color in the app references this enum — no ad-hoc hex values.
enum Forge {

    // ── Foundations (Deeper, Richer Cosmic Space Void) ──
    static let obsidian     = Color(red: 0.008, green: 0.008, blue: 0.016)   // #020204
    static let abyss        = Color(red: 0.004, green: 0.004, blue: 0.008)   // #010102
    static let phantom      = Color(red: 0.016, green: 0.012, blue: 0.031)   // #040308

    // ── Primary Accents (Ultra-Vibrant Glowing Cyberpunk) ──
    static let arcane       = Color(red: 0.52, green: 0.15, blue: 1.0)       // #8426FF (Electric Violet)
    static let cipher       = Color(red: 0.0, green: 0.85, blue: 0.95)       // #00D8F2 (Hyper-Neon Cyan)
    static let supernova    = Color(red: 1.0, green: 0.15, blue: 0.65)       // #FF26A6 (Vivid Neon Magenta)

    // ── Signal Colors (Glowing Burning Fire) ──
    static let ember        = Color(red: 1.0, green: 0.45, blue: 0.0)        // #FF7300 (Vivid Safety Orange)
    static let crimson      = Color(red: 1.0, green: 0.15, blue: 0.25)       // #FF263F (Glowing Crimson Red)

    // ── Terminal & Success (Acid Jade/Mint) ──
    static let jade         = Color(red: 0.0, green: 0.95, blue: 0.45)       // #00F273 (Electric Jade)
    static let mint         = Color(red: 0.1, green: 0.98, blue: 0.65)       // #1AFFA6 (Glowing Neon Mint)

    // ── Neutrals (Premium Metallic Steel) ──
    static let frost        = Color(red: 0.94, green: 0.96, blue: 0.99)       // #F0F5FC (Luminous Ice)
    static let steel        = Color(red: 0.48, green: 0.54, blue: 0.64)       // #7A8AA3 (Chrome Steel)
    static let ash          = Color(red: 0.20, green: 0.24, blue: 0.30)       // #333D4D (Dark Charcoal)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Glassmorphism Background
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct GlassmorphismBG: View {

    @State private var breathe: CGFloat = 0
    @State private var scanOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Forge.abyss.ignoresSafeArea()                                  // L0
            perspectiveGrid.ignoresSafeArea().opacity(0.04)                // L1
            auroraOrbs.ignoresSafeArea().blur(radius: 140).opacity(0.45)   // L2
            dragonWatermark.ignoresSafeArea()                              // L3
            scanlines.ignoresSafeArea().opacity(0.025).blendMode(.overlay) // L4
            vignette.ignoresSafeArea()                                     // L5
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { breathe = 1 }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) { scanOffset = 1 }
        }
    }

    // MARK: - L1: Perspective Grid

    private var perspectiveGrid: some View {
        Canvas { ctx, size in
            let cols = 28
            let sp = size.width / CGFloat(cols)
            for i in 0...cols {
                var p = Path()
                p.move(to: CGPoint(x: CGFloat(i) * sp, y: size.height * 0.55))
                p.addLine(to: CGPoint(x: CGFloat(i) * sp, y: size.height))
                ctx.stroke(p, with: .color(Forge.cipher.opacity(0.12)), style: StrokeStyle(lineWidth: 0.4))
            }
            for i in 0...18 {
                let t = CGFloat(i) / 18
                let y = size.height * (0.55 + t * 0.45)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(Forge.arcane.opacity(0.06 + t * t * 0.12)), style: StrokeStyle(lineWidth: 0.35))
            }
        }
    }

    // MARK: - L2: Aurora Orbs

    private var auroraOrbs: some View {
        Canvas { ctx, size in
            let minDim = min(size.width, size.height)

            // Arcane orb — top left
            let p1 = CGPoint(x: size.width * (0.14 + 0.09 * sin(breathe * .pi)),
                             y: size.height * (0.16 + 0.11 * cos(breathe * .pi)))
            let r1 = minDim * (0.40 + 0.12 * breathe)
            ctx.drawLayer { c in
                c.fill(Path(ellipseIn: CGRect(x: p1.x - r1, y: p1.y - r1, width: r1 * 2, height: r1 * 2)),
                       with: .radialGradient(Gradient(colors: [Forge.arcane.opacity(0.55), .clear]),
                                             center: p1, startRadius: 0, endRadius: r1))
            }

            // Cipher orb — bottom right
            let p2 = CGPoint(x: size.width * (0.84 - 0.07 * cos(breathe * .pi)),
                             y: size.height * (0.78 - 0.09 * sin(breathe * .pi)))
            let r2 = minDim * (0.34 + 0.09 * breathe)
            ctx.drawLayer { c in
                c.fill(Path(ellipseIn: CGRect(x: p2.x - r2, y: p2.y - r2, width: r2 * 2, height: r2 * 2)),
                       with: .radialGradient(Gradient(colors: [Forge.cipher.opacity(0.40), .clear]),
                                             center: p2, startRadius: 0, endRadius: r2))
            }

            // Ember accent — center bottom
            let p3 = CGPoint(x: size.width * (0.48 + 0.05 * sin(breathe * .pi * 1.3)),
                             y: size.height * (0.90 - 0.06 * breathe))
            let r3 = minDim * (0.22 + 0.06 * breathe)
            ctx.drawLayer { c in
                c.fill(Path(ellipseIn: CGRect(x: p3.x - r3, y: p3.y - r3, width: r3 * 2, height: r3 * 2)),
                       with: .radialGradient(Gradient(colors: [Forge.ember.opacity(0.12), .clear]),
                                             center: p3, startRadius: 0, endRadius: r3))
            }
        }
    }

    // MARK: - L3: Dragon Watermark

    private var dragonWatermark: some View {
        let art: [String] = [
            "  +--------------------------------------------------------+",
            "  | [SYSTEM: MIDNIGHT_DRAGON]                 [SECTOR: 09] |",
            "  +--------------------------------------------------------+",
            "  |                                                        |",
            "  |               _===~_  _~===_                           |",
            "  |         _--^^#####//     \\#####^^--_                  |",
            "  |      _-^##########// ( ) \\##########^-_               |",
            "  |     -############// |\\^^/| \\############-            |",
            "  |   _/############//  (o::o)  \\############\\_          |",
            "  |  /#############((    \\//    ))#############\\         |",
            "  | -###############\\\\  (    )  //###############-       |",
            "  |-#################\\\\ / VV \\ //#################-     |",
            "  |-###################\\\\/    \\\\//###################- |",
            "  |_#/|##########/\\######(  /\\  )######/\\##########|\\#_|",
            "  ||/  |#/\\#/\\#/\\  \\#/\\##\\ |  | /##/\\#/ /\\#/\\#/\\#|\\|     |",
            "  |`   |/  V  V `   V \\#\\| |  | |/#/ V  ` V  V  \\|   `  |",
            "  |    `   `  `      ` / | |  | | \\ `     `  `   `        |",
            "  |                    (  | |  | |  )                      |",
            "  |                   __\\ | |  | | /__                    |",
            "  |                  (vvv(VVV)(VVV)vvv)                    |",
            "  |                                                        |",
            "  +--------------------------------------------------------+",
            "  | [BLUEPRINT v2.0]        [CORE_CORE]       [SCALE: 100] |",
            "  +--------------------------------------------------------+"
        ]
        return VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(art.enumerated()), id: \.offset) { i, line in
                        Group {
                            if i >= 4 && i <= 19 {
                                DragonArtRenderer.tokenizeDragonLine(line, row: i - 4, pulse: Double(breathe))
                            } else {
                                DragonArtRenderer.tokenizeBorderLine(line)
                            }
                        }
                        .font(.system(size: 5.5, weight: .light, design: .monospaced))
                    }
                }
                .opacity(0.06)
                .padding(.trailing, 24).padding(.bottom, 16)
            }
        }
    }

    // MARK: - L4: CRT Scanlines

    private var scanlines: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let sp: CGFloat = 2.5
                for i in 0..<Int(size.height / sp) {
                    let y = CGFloat(i) * sp
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(.white.opacity(0.035)), style: StrokeStyle(lineWidth: 0.4))
                }
                let beamY = (scanOffset * geo.size.height).truncatingRemainder(dividingBy: size.height)
                var b = Path(); b.move(to: CGPoint(x: 0, y: beamY)); b.addLine(to: CGPoint(x: size.width, y: beamY))
                ctx.stroke(b, with: .color(Forge.cipher.opacity(0.06)), style: StrokeStyle(lineWidth: 1.5))
            }
        }
    }

    // MARK: - L5: Vignette

    private var vignette: some View {
        RadialGradient(colors: [.clear, Forge.abyss.opacity(0.75)],
                       center: .center, startRadius: 250, endRadius: 750)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - GlassCard ViewModifier
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Applies a frosted glass card effect with configurable corner radius,
/// border gradient, and colored outer glow shadow.
struct GlassCard: ViewModifier {
    var radius: CGFloat = 22
    var border: CGFloat = 0.08
    var glow: Color = Forge.arcane

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Forge.obsidian.opacity(0.85))
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial.opacity(0.06))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(border), .white.opacity(border * 0.15)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: glow.opacity(0.05), radius: 35, y: 10)
            .shadow(color: .black.opacity(0.55), radius: 18, y: 6)
    }
}

extension View {
    /// Wraps the view in a frosted glass card with neon outer glow.
    func glassCard(radius: CGFloat = 22, border: CGFloat = 0.08, glow: Color = Forge.arcane) -> some View {
        modifier(GlassCard(radius: radius, border: border, glow: glow))
    }
}

#Preview { GlassmorphismBG().preferredColorScheme(.dark) }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Dragon Art Renderer & Color Interpolation Utilities
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct DragonArtRenderer {
    static func getDragonCharColor(char: Character, row: Int, col: Int, pulse: Double = 0.5) -> Color {
        if char == " " {
            return Forge.steel.opacity(0.12)
        }
        
        // Glowing Eyes in Row 4
        if row == 4 && (char == "o" || char == ":") {
            return Color.interpolate(from: Forge.crimson, to: Forge.supernova, fraction: pulse)
        }
        
        // Glowing Core in Row 7
        if row == 7 && char == "V" {
            return Color.interpolate(from: Forge.ember, to: Forge.supernova, fraction: pulse)
        }
        
        // Claws/Talons
        if row == 15 && char == "V" {
            return Forge.supernova
        }
        if row == 15 && char == "v" {
            return Forge.steel
        }
        
        // Body Scales '#' with vertical gradient
        if char == "#" {
            let ratio = Double(row) / 15.0
            if ratio < 0.3 {
                return Color.interpolate(from: Forge.cipher, to: Forge.jade, fraction: ratio / 0.3)
            } else if ratio < 0.7 {
                return Color.interpolate(from: Forge.jade, to: Forge.arcane, fraction: (ratio - 0.3) / 0.4)
            } else {
                return Color.interpolate(from: Forge.arcane, to: Forge.ember, fraction: (ratio - 0.7) / 0.3)
            }
        }
        
        // Horns / Crown in Row 0
        if row == 0 && (char == "=" || char == "~" || char == "_") {
            return Forge.supernova
        }
        
        if char == "/" || char == "\\" {
            return Forge.arcane.opacity(0.8)
        }
        
        if char == "(" || char == ")" {
            return Forge.cipher.opacity(0.8)
        }
        
        return Forge.steel.opacity(0.6)
    }
    
    static func tokenizeDragonLine(_ line: String, row: Int, pulse: Double = 0.5) -> some View {
        var middle = line
        var prefixText = ""
        var suffixText = ""
        
        if middle.hasPrefix("  | ") {
            prefixText = "  | "
            middle.removeFirst(4)
        } else if middle.hasPrefix("  |") {
            prefixText = "  |"
            middle.removeFirst(3)
        }
        
        if middle.hasSuffix(" |") {
            suffixText = " |"
            middle.removeLast(2)
        } else if middle.hasSuffix("|") {
            suffixText = "|"
            middle.removeLast(1)
        }
        
        return HStack(spacing: 0) {
            if !prefixText.isEmpty {
                Text(prefixText).foregroundColor(Forge.steel.opacity(0.3))
            }
            
            // Build the middle tokenized text
            Self.buildTokenizedText(middle, row: row, pulse: pulse)
            
            if !suffixText.isEmpty {
                Text(suffixText).foregroundColor(Forge.steel.opacity(0.3))
            }
        }
    }
    
    static func buildTokenizedText(_ text: String, row: Int, pulse: Double) -> some View {
        var segments: [(String, Color)] = []
        var currentGroup = ""
        var currentColor: Color? = nil
        
        for (col, char) in text.enumerated() {
            let charColor = self.getDragonCharColor(char: char, row: row, col: col, pulse: pulse)
            if let activeColor = currentColor {
                if activeColor == charColor {
                    currentGroup.append(char)
                } else {
                    segments.append((currentGroup, activeColor))
                    currentGroup = String(char)
                    currentColor = charColor
                }
            } else {
                currentGroup = String(char)
                currentColor = charColor
            }
        }
        
        if !currentGroup.isEmpty, let activeColor = currentColor {
            segments.append((currentGroup, activeColor))
        }
        
        return HStack(spacing: 0) {
            ForEach(0..<segments.count, id: \.self) { idx in
                Text(segments[idx].0).foregroundColor(segments[idx].1)
            }
        }
    }
    
    @ViewBuilder
    static func tokenizeBorderLine(_ line: String) -> some View {
        if line.contains("SYSTEM: MIDNIGHT_DRAGON") {
            HStack(spacing: 0) {
                Text("  | ").foregroundColor(Forge.steel.opacity(0.3))
                Text("[").foregroundColor(Forge.steel.opacity(0.5))
                Text("SYSTEM: ").foregroundColor(Forge.steel.opacity(0.5))
                Text("MIDNIGHT_DRAGON").foregroundColor(Forge.ember).bold()
                Text("]").foregroundColor(Forge.steel.opacity(0.5))
                Text("                 ").foregroundColor(.clear)
                Text("[").foregroundColor(Forge.steel.opacity(0.5))
                Text("SECTOR: ").foregroundColor(Forge.steel.opacity(0.5))
                Text("09").foregroundColor(Forge.jade).bold()
                Text("]").foregroundColor(Forge.steel.opacity(0.5))
                Text(" |").foregroundColor(Forge.steel.opacity(0.3))
            }
        } else if line.contains("BLUEPRINT") {
            HStack(spacing: 0) {
                Text("  | ").foregroundColor(Forge.steel.opacity(0.3))
                Text("[").foregroundColor(Forge.steel.opacity(0.5))
                Text("BLUEPRINT ").foregroundColor(Forge.steel.opacity(0.5))
                Text("v2.1").foregroundColor(Forge.supernova).bold()
                Text("]").foregroundColor(Forge.steel.opacity(0.5))
                Text("        ").foregroundColor(.clear)
                Text("[").foregroundColor(Forge.steel.opacity(0.5))
                Text("CORE_CORE").foregroundColor(Forge.jade).bold()
                Text("]").foregroundColor(Forge.steel.opacity(0.5))
                Text("       ").foregroundColor(.clear)
                Text("[").foregroundColor(Forge.steel.opacity(0.5))
                Text("SCALE: ").foregroundColor(Forge.steel.opacity(0.5))
                Text("100%").foregroundColor(Forge.cipher).bold()
                Text("]").foregroundColor(Forge.steel.opacity(0.5))
                Text(" |").foregroundColor(Forge.steel.opacity(0.3))
            }
        } else {
            Text(line).foregroundColor(Forge.steel.opacity(0.35))
        }
    }
}

extension Color {
    static func interpolate(from color1: Color, to color2: Color, fraction: Double) -> Color {
        #if canImport(UIKit)
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * CGFloat(fraction)
        let g = g1 + (g2 - g1) * CGFloat(fraction)
        let b = b1 + (b2 - b1) * CGFloat(fraction)
        let a = a1 + (a2 - a1) * CGFloat(fraction)
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
        #else
        return color1
        #endif
    }
}
