//
//  GlassmorphismBG.swift
//  HC
//
//  Neo-Tokyo Data Terminal — Vantablack canvas, breathing halos,
//  CRT scanlines, dragon silhouette, and animated grid.
//

import SwiftUI

// MARK: - Color Constants

enum NeoTokyo {
    // Vantablack
    static let vantablack      = Color(red: 0.020, green: 0.020, blue: 0.020)
    static let vantablackDeep  = Color(red: 0.008, green: 0.008, blue: 0.012)

    // Neon Palette
    static let neonPurple      = Color(red: 0.749, green: 0.251, blue: 1.000) // #BF40FF
    static let neonCyan        = Color(red: 0.000, green: 0.961, blue: 1.000) // #00F5FF
    static let laserRed        = Color(red: 1.000, green: 0.090, blue: 0.267) // #FF1744
    static let laserGold       = Color(red: 1.000, green: 0.843, blue: 0.000) // #FFD700

    // Glass surface
    static let glassStroke     = Color.white.opacity(0.08)
    static let glassFill       = Color.white.opacity(0.04)

    // Terminal green for typing log
    static let terminalGreen   = Color(red: 0.180, green: 1.000, blue: 0.529) // #2EFF87

    // Additional accents
    static let deepIndigo      = Color(red: 0.180, green: 0.090, blue: 0.420)
    static let plasmaPink      = Color(red: 1.000, green: 0.200, blue: 0.600)
}

// MARK: - Glassmorphism Background

struct GlassmorphismBG: View {
    @State private var breathePhase: CGFloat = 0
    @State private var gridPhase: CGFloat = 0
    @State private var scanlineOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // ── Layer 0: Abyss ──
            NeoTokyo.vantablackDeep
                .ignoresSafeArea()

            // ── Layer 1: Perspective grid floor ──
            perspectiveGrid
                .ignoresSafeArea()
                .opacity(0.06)

            // ── Layer 2: Breathing Neon Halos (3 orbs) ──
            breathingHalos
                .ignoresSafeArea()
                .blur(radius: 130)
                .opacity(0.50)

            // ── Layer 3: Dragon silhouette ──
            dragonWatermark
                .ignoresSafeArea()

            // ── Layer 4: CRT scanlines ──
            scanlines
                .ignoresSafeArea()
                .opacity(0.035)
                .blendMode(.overlay)

            // ── Layer 5: Vignette ──
            RadialGradient(
                colors: [.clear, NeoTokyo.vantablackDeep.opacity(0.7)],
                center: .center,
                startRadius: 200,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                gridPhase = 1
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                scanlineOffset = 1
            }
        }
    }

    // MARK: - Breathing Halos (3 orbs)

    private var breathingHalos: some View {
        Canvas { context, size in
            // Purple halo — top-left
            let p1 = CGPoint(
                x: size.width * (0.15 + 0.08 * sin(breathePhase * .pi)),
                y: size.height * (0.18 + 0.10 * cos(breathePhase * .pi))
            )
            let r1 = min(size.width, size.height) * (0.38 + 0.10 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p1.x - r1, y: p1.y - r1, width: r1 * 2, height: r1 * 2)),
                    with: .radialGradient(
                        Gradient(colors: [NeoTokyo.neonPurple.opacity(0.5), .clear]),
                        center: p1, startRadius: 0, endRadius: r1
                    )
                )
            }

            // Cyan halo — bottom-right
            let p2 = CGPoint(
                x: size.width * (0.82 - 0.06 * cos(breathePhase * .pi)),
                y: size.height * (0.75 - 0.08 * sin(breathePhase * .pi))
            )
            let r2 = min(size.width, size.height) * (0.32 + 0.08 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p2.x - r2, y: p2.y - r2, width: r2 * 2, height: r2 * 2)),
                    with: .radialGradient(
                        Gradient(colors: [NeoTokyo.neonCyan.opacity(0.35), .clear]),
                        center: p2, startRadius: 0, endRadius: r2
                    )
                )
            }

            // Red/gold accent — center bottom
            let p3 = CGPoint(
                x: size.width * (0.50 + 0.04 * sin(breathePhase * .pi * 1.5)),
                y: size.height * (0.88 - 0.05 * breathePhase)
            )
            let r3 = min(size.width, size.height) * (0.20 + 0.05 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p3.x - r3, y: p3.y - r3, width: r3 * 2, height: r3 * 2)),
                    with: .radialGradient(
                        Gradient(colors: [NeoTokyo.laserRed.opacity(0.15), .clear]),
                        center: p3, startRadius: 0, endRadius: r3
                    )
                )
            }
        }
    }

    // MARK: - Perspective Grid

    private var perspectiveGrid: some View {
        Canvas { context, size in
            let lineCount = 24
            let spacing = size.width / CGFloat(lineCount)

            // Vertical lines
            for i in 0...lineCount {
                let x = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height * 0.5))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(NeoTokyo.neonCyan.opacity(0.15)),
                               style: StrokeStyle(lineWidth: 0.5))
            }

            // Horizontal lines with perspective convergence
            let hLines = 16
            for i in 0...hLines {
                let progress = CGFloat(i) / CGFloat(hLines)
                let y = size.height * (0.5 + progress * 0.5)
                let fade = progress * progress // accelerate opacity toward bottom
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(NeoTokyo.neonPurple.opacity(0.08 + fade * 0.15)),
                               style: StrokeStyle(lineWidth: 0.4))
            }
        }
    }

    // MARK: - Dragon Silhouette Watermark

    private var dragonWatermark: some View {
        let dragon = """
                       ⠀⠀⠀⠀⠀⠀⣀⣤⣶⣿⣿⣶⣤⣀
                   ⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄
                 ⠀⠀⠀⣴⣿⣿⣿⣿⣿⡿⠿⠿⣿⣿⣿⣿⣿⣦
               ⠀⠀⣼⣿⣿⣿⡿⠋⠁⠀⠀⠀⠀⠀⠈⠙⢿⣿⣿⣿⣧
              ⠀⣼⣿⣿⣿⠏⠀⠀⠀⠀⠀⣀⣀⠀⠀⠀⠀⠹⣿⣿⣿⣧
             ⢸⣿⣿⣿⡟⠀⠀⠀⠀⢠⣾⣿⣿⣷⡄⠀⠀⠀⢻⣿⣿⣿⡇
             ⣿⣿⣿⣿⠃⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠸⣿⣿⣿⡇
            ⢸⣿⣿⣿⡇⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⢸⣿⣿⣿⡇
            ⠘⣿⣿⣿⡇⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⢸⣿⣿⣿⠃
             ⠹⣿⣿⣿⡄⠀⠀⠀⠀⠸⣿⣿⣿⡿⠀⠀⠀⠀⠀⣼⣿⣿⡿⠁
              ⠙⣿⣿⣿⣆⠀⠀⠀⠀⠀⠛⠛⠛⠀⠀⠀⠀⢀⣾⣿⣿⡿⠃
                ⠙⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⠟⠁
                  ⠙⢿⣿⣿⣷⣤⣀⠀⠀⠀⣀⣤⣾⣿⣿⡿⠟⠁
                     ⠉⠻⢿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠋⠁
                          ⠈⠉⠛⠛⠛⠛⠉⠁
        """

        return VStack {
            Spacer()
            HStack {
                Spacer()
                Text(dragon)
                    .font(.system(size: 7, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                NeoTokyo.laserRed.opacity(0.06),
                                NeoTokyo.laserGold.opacity(0.04),
                                NeoTokyo.neonPurple.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.trailing, 40)
                    .padding(.bottom, 30)
            }
        }
    }

    // MARK: - CRT Scanlines

    private var scanlines: some View {
        GeometryReader { geo in
            let offset = scanlineOffset * geo.size.height
            Canvas { context, size in
                let lineSpacing: CGFloat = 3
                let count = Int(size.height / lineSpacing) + 1
                for i in 0..<count {
                    let y = CGFloat(i) * lineSpacing
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.04)),
                                   style: StrokeStyle(lineWidth: 0.5))
                }

                // Bright scan beam
                let beamY = offset.truncatingRemainder(dividingBy: size.height)
                var beam = Path()
                beam.move(to: CGPoint(x: 0, y: beamY))
                beam.addLine(to: CGPoint(x: size.width, y: beamY))
                context.stroke(beam, with: .color(NeoTokyo.neonCyan.opacity(0.08)),
                               style: StrokeStyle(lineWidth: 2))
            }
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var strokeOpacity: CGFloat = 0.10
    var glowColor: Color = NeoTokyo.neonPurple

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(NeoTokyo.vantablack.opacity(0.80))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.08))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.2),
                                Color.white.opacity(strokeOpacity * 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: glowColor.opacity(0.06), radius: 40, x: 0, y: 12)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, strokeOpacity: CGFloat = 0.10, glowColor: Color = NeoTokyo.neonPurple) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, glowColor: glowColor))
    }
}

#Preview {
    GlassmorphismBG()
        .preferredColorScheme(.dark)
}
