//
//  GlassmorphismBG.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  MIDNIGHT FORGE — Visual Foundation Layer                    ║
//  ║                                                               ║
//  ║  This file defines the entire color system ("Forge" palette) ║
//  ║  and the multi-layered background composition:                ║
//  ║    L0: Obsidian void                                          ║
//  ║    L1: Retro-futuristic perspective grid                     ║
//  ║    L2: Three breathing aurora orbs                            ║
//  ║    L3: Detailed ASCII dragon watermark                        ║
//  ║    L4: CRT phosphor scanlines + sweep beam                   ║
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

    // ── Foundations ──
    static let obsidian     = Color(red: 0.027, green: 0.027, blue: 0.055)   // #07070E
    static let abyss        = Color(red: 0.020, green: 0.020, blue: 0.043)   // #05050B
    static let phantom      = Color(red: 0.075, green: 0.055, blue: 0.180)   // #130E2E

    // ── Primary Accents ──
    static let arcane       = Color(red: 0.545, green: 0.235, blue: 0.985)   // #8B3CFC
    static let cipher       = Color(red: 0.024, green: 0.714, blue: 0.831)   // #06B6D4
    static let supernova    = Color(red: 0.659, green: 0.333, blue: 0.969)   // #A855F7

    // ── Signal Colors ──
    static let ember        = Color(red: 0.961, green: 0.620, blue: 0.043)   // #F59E0B
    static let crimson      = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444

    // ── Terminal & Success ──
    static let jade         = Color(red: 0.063, green: 0.725, blue: 0.506)   // #10B981
    static let mint         = Color(red: 0.204, green: 0.827, blue: 0.600)   // #34D399

    // ── Neutrals ──
    static let frost        = Color(red: 0.886, green: 0.910, blue: 0.941)   // #E2E8F0
    static let steel        = Color(red: 0.392, green: 0.455, blue: 0.545)   // #64748B
    static let ash          = Color(red: 0.255, green: 0.298, blue: 0.369)   // #414C5E
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
            "                         __                  __",
            "                        ( _)                ( _)",
            "                       / / \\\\              / /\\_\\",
            "                      / /   \\\\            / / | \\ \\",
            "                     / /     \\\\ \\  /\\  / / /  |  \\ \\",
            "                    /  /   ,  \\\\ \\/ /\\/ / /   |   \\ |",
            "                   /  /    |\\  \\\\  /  / / / \\ |   / |",
            "                  /  /     | \\  \\\\, / / /   \\|  / /",
            "                 /  /      |  \\  \\ / / / \\   / / /",
            "                |  /       |   \\  / / /   \\ / / /",
            "                | |        |    \\/ / /    / / /",
            "                | |        |     |/ /    / /|/",
            "                | |        |     / /    / / |",
            "                | |        |    / /    / /  |",
            "                 \\  \\      |   / /    / /   |",
            "                  \\  \\     |  / /    / /    |",
            "                   \\  \\    | / /    / /     |",
            "                    \\  \\ __/ / ____/ /      |",
            "                     \\___/ \\/______/       /"
        ]
        return VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(art.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 5.5, weight: .light, design: .monospaced))
                    }
                }
                .foregroundStyle(
                    LinearGradient(colors: [Forge.arcane.opacity(0.04), Forge.ember.opacity(0.03), Forge.cipher.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
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
