//
//  GlitchFlipContainer.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  3D GLITCH / SHATTER TRANSITION ENGINE                       ║
//  ║                                                               ║
//  ║  Drives a three-phase animation between two child views:      ║
//  ║    Phase 1 — Pre-distortion build (chromatic split + noise)   ║
//  ║    Phase 2 — The flip (rotation + peak glitch artifacts)      ║
//  ║    Phase 3 — Settle (all distortion fades to zero)            ║
//  ║                                                               ║
//  ║  Visual FX layers:                                            ║
//  ║    • Chromatic aberration (cyan/crimson offset rectangles)     ║
//  ║    • Horizontal slice displacement (8 strips)                 ║
//  ║    • Scan-noise overlay (40 randomized strips)                ║
//  ║    • Heavy haptic impact at rotation midpoint                 ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

/// Generic container that flips between a front and back view
/// using a custom chromatic-aberration glitch effect.
struct GlitchFlipContainer<Front: View, Back: View>: View {

    /// External binding that triggers the flip animation on change.
    @Binding var isFlipped: Bool

    /// Builder closure for the front-facing view (Calendar).
    let front: () -> Front

    /// Builder closure for the back-facing view (Timesheet).
    let back: () -> Back

    // ── Animation State ─────────────────────────────────────────

    /// Current Y-axis rotation angle in degrees (0 = front, 180 = back).
    @State private var rotation: Double = 0

    /// Glitch intensity multiplier (0 = clean, 1 = full distortion).
    @State private var glitch: CGFloat = 0

    /// Scan-noise overlay opacity multiplier.
    @State private var noise: CGFloat = 0

    /// Chromatic aberration offset distance in points.
    @State private var split: CGFloat = 0

    /// Per-slice horizontal displacement offsets (8 horizontal strips).
    @State private var offsets: [CGSize] = Array(repeating: .zero, count: 8)

    /// Per-slice opacity values for the displacement strips.
    @State private var sliceAlpha: [CGFloat] = Array(repeating: 1, count: 8)

    /// Total animation duration in seconds across all three phases.
    private let dur: Double = 0.55

    /// Haptic generator pre-warmed before each flip for zero-latency impact.
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        ZStack {
            ZStack {
                front().opacity(rotation < 90 ? 1 : 0)
                back().rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(rotation >= 90 ? 1 : 0)
            }
            .rotation3DEffect(.degrees(rotation),
                              axis: (x: 0.04 * glitch, y: 1, z: 0.015 * glitch),
                              perspective: 0.35)

            if glitch > 0 { artifacts }
        }
        .onChange(of: isFlipped) { _, val in flip(to: val) }
    }

    // MARK: - Glitch Artifacts

    private var artifacts: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Forge.cipher.opacity(0.08 * glitch))
                .offset(x: split, y: -split * 0.4).blendMode(.screen)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Forge.crimson.opacity(0.06 * glitch))
                .offset(x: -split, y: split * 0.25).blendMode(.screen)

            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle().fill(Color.white.opacity(0.03 * sliceAlpha[i]))
                        .frame(height: 10).offset(offsets[i]).opacity(Double(sliceAlpha[i]))
                }
            }.blendMode(.overlay)

            VStack(spacing: 1.5) {
                ForEach(0..<40, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(Double.random(in: 0...0.05) * Double(noise)))
                        .frame(height: CGFloat.random(in: 0.5...2.5))
                }
            }.blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Three-Phase Flip Animation

    /// Orchestrates the three-phase glitch transition.
    ///
    /// Timeline (0.55s total):
    /// - `0.00s–0.10s`: Pre-distortion build — ramp glitch/split/noise, scatter slices
    /// - `0.10s–0.35s`: Core flip — rotate to target angle with peak artifacts
    /// - `0.36s–0.55s`: Settle — all distortion animates back to zero
    private func flip(to flipped: Bool) {
        haptic.prepare()

        withAnimation(.easeIn(duration: dur * 0.18)) {
            glitch = 1; split = CGFloat.random(in: 5...12); noise = 0.85; scatter()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dur * 0.18) {
            haptic.impactOccurred(intensity: 1.0)
            withAnimation(.easeInOut(duration: dur * 0.45)) {
                rotation = flipped ? 180 : 0
                split = CGFloat.random(in: -16...16); scatter()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dur * 0.65) {
            withAnimation(.easeOut(duration: dur * 0.35)) {
                glitch = 0; split = 0; noise = 0
                offsets = Array(repeating: .zero, count: 8)
                sliceAlpha = Array(repeating: 1, count: 8)
            }
        }
    }

    /// Randomizes horizontal slice offsets and opacity values to create
    /// the characteristic "shattered glass" displacement effect.
    private func scatter() {
        for i in 0..<8 {
            offsets[i] = CGSize(width: .random(in: -22...22), height: .random(in: -3...3))
            sliceAlpha[i] = .random(in: 0.25...1.0)
        }
    }
}

#Preview {
    @Previewable @State var flipped = false
    ZStack {
        Forge.obsidian.ignoresSafeArea()
        VStack(spacing: 30) {
            GlitchFlipContainer(isFlipped: $flipped) {
                RoundedRectangle(cornerRadius: 22).fill(Forge.arcane.opacity(0.3))
                    .frame(width: 320, height: 400).overlay(Text("FRONT").foregroundColor(.white))
            } back: {
                RoundedRectangle(cornerRadius: 22).fill(Forge.cipher.opacity(0.3))
                    .frame(width: 320, height: 400).overlay(Text("BACK").foregroundColor(.white))
            }
            Button("FLIP") { flipped.toggle() }.foregroundColor(Forge.cipher)
        }
    }.preferredColorScheme(.dark)
}
