//
//  GlassmorphismBG.swift
//  HC
//
//  Neo-Tokyo Data Terminal — Vantablack canvas with breathing neon halos.
//

import SwiftUI

// MARK: - Color Constants

enum NeoTokyo {
    // Vantablack
    static let vantablack      = Color(red: 0.020, green: 0.020, blue: 0.020)
    static let vantablackDeep  = Color(red: 0.012, green: 0.012, blue: 0.015)

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
}

// MARK: - Glassmorphism Background

struct GlassmorphismBG: View {
    @State private var breathePhase: CGFloat = 0
    @State private var grainSeed: CGFloat = 0

    var body: some View {
        ZStack {
            // ── Layer 0: Vantablack ──
            NeoTokyo.vantablackDeep
                .ignoresSafeArea()

            // ── Layer 1: Breathing Neon Halos ──
            breathingHalos
                .ignoresSafeArea()
                .blur(radius: 120)
                .opacity(0.55)

            // ── Layer 2: Subtle grain texture ──
            GrainOverlay(seed: grainSeed)
                .opacity(0.03)
                .ignoresSafeArea()
                .blendMode(.overlay)

            // ── Layer 3: Watermark Placeholder (Laser Red/Gold) ──
            watermarkPlaceholder
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
            // Subtle grain animation
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                grainSeed = CGFloat.random(in: 0...1000)
            }
        }
    }

    // MARK: - Breathing Halos

    private var breathingHalos: some View {
        Canvas { context, size in
            // Purple halo — top-left drift
            let purpleCenter = CGPoint(
                x: size.width * (0.18 + 0.06 * sin(breathePhase * .pi)),
                y: size.height * (0.22 + 0.08 * cos(breathePhase * .pi))
            )
            let purpleRadius = min(size.width, size.height) * (0.35 + 0.08 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: purpleCenter.x - purpleRadius,
                        y: purpleCenter.y - purpleRadius,
                        width: purpleRadius * 2,
                        height: purpleRadius * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            NeoTokyo.neonPurple.opacity(0.45),
                            NeoTokyo.neonPurple.opacity(0.0)
                        ]),
                        center: purpleCenter,
                        startRadius: 0,
                        endRadius: purpleRadius
                    )
                )
            }

            // Cyan halo — bottom-right drift
            let cyanCenter = CGPoint(
                x: size.width * (0.78 - 0.05 * cos(breathePhase * .pi)),
                y: size.height * (0.72 - 0.06 * sin(breathePhase * .pi))
            )
            let cyanRadius = min(size.width, size.height) * (0.30 + 0.06 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: cyanCenter.x - cyanRadius,
                        y: cyanCenter.y - cyanRadius,
                        width: cyanRadius * 2,
                        height: cyanRadius * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            NeoTokyo.neonCyan.opacity(0.35),
                            NeoTokyo.neonCyan.opacity(0.0)
                        ]),
                        center: cyanCenter,
                        startRadius: 0,
                        endRadius: cyanRadius
                    )
                )
            }
        }
    }

    // MARK: - Watermark Placeholder

    private var watermarkPlaceholder: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("HC")
                    .font(.system(size: 140, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                NeoTokyo.laserRed.opacity(0.04),
                                NeoTokyo.laserGold.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(-12))
                    .padding(.trailing, 60)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Grain Overlay

struct GrainOverlay: View {
    let seed: CGFloat

    var body: some View {
        Canvas { context, size in
            // Procedural noise via tiny rectangles
            let cellSize: CGFloat = 3
            for x in stride(from: 0, to: size.width, by: cellSize) {
                for y in stride(from: 0, to: size.height, by: cellSize) {
                    let noise = CGFloat.random(in: 0...1)
                    let opacity = noise * 0.5
                    context.fill(
                        Path(CGRect(x: x, y: y, width: cellSize, height: cellSize)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var strokeOpacity: CGFloat = 0.10

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.15))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(NeoTokyo.vantablack.opacity(0.75))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: NeoTokyo.neonPurple.opacity(0.08), radius: 30, x: 0, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, strokeOpacity: CGFloat = 0.10) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

#Preview {
    GlassmorphismBG()
        .preferredColorScheme(.dark)
}
