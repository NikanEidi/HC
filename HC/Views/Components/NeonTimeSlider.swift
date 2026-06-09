//
//  NeonTimeSlider.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  Custom time input slider with haptic 15-minute snapping.    ║
//  ║  Features triple-gradient track, glowing thumb with pulse    ║
//  ║  ring, hourly tick marks, and split H:MM readout.            ║
//  ║  Fully compatible with Apple Pencil drag + hover.            ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

/// A frictionless neon-styled time slider that snaps to 15-minute intervals.
/// Emits haptic feedback on each snap increment during drag gestures.
struct NeonTimeSlider: View {

    /// Display label (e.g. "FROM", "TO").
    let label: String

    /// Current value in total minutes from midnight (0-1440).
    @Binding var minutes: Int

    /// Track and thumb accent color.
    var accent: Color = Forge.cipher

    // Optional properties for geometry reporting
    var sessionID: UUID? = nil
    var isStartSlider: Bool = true

    // ── Configuration ──
    private let step = 15
    private let range = 0...1440

    // ── State ──
    @State private var dragging = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── Label + Time Readout ──
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(Forge.steel)
                    .tracking(2.5)

                Spacer()

                HStack(spacing: 0) {
                    Text(String(format: "%02d", minutes / 60))
                        .foregroundColor(accent)
                    Text(":")
                        .foregroundColor(accent.opacity(0.4))
                    Text(String(format: "%02d", minutes % 60))
                        .foregroundColor(accent)
                }
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .shadow(color: accent.opacity(dragging ? 0.7 : 0.25), radius: dragging ? 18 : 6)
                .animation(.easeOut(duration: 0.15), value: dragging)
            }

            // ── Slider Track ──
            GeometryReader { geo in
                let w = geo.size.width
                let pct = CGFloat(minutes) / 1440.0
                let x = max(0, min(w, pct * w))

                ZStack(alignment: .leading) {
                    // Background
                    Capsule().fill(Forge.ash.opacity(0.18)).frame(height: 4)

                    // Tick marks
                    HStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { _ in
                            Spacer()
                            Rectangle().fill(Forge.frost.opacity(0.04)).frame(width: 0.5, height: 10)
                        }
                        Spacer()
                    }.frame(height: 4)

                    // Active fill
                    Capsule()
                        .fill(LinearGradient(colors: [accent.opacity(0.3), accent.opacity(0.7), accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: x, height: 4)
                        .shadow(color: accent.opacity(dragging ? 0.45 : 0.15), radius: dragging ? 14 : 5)
                        .animation(.spring(response: 0.12, dampingFraction: 0.85), value: x)

                    // Thumb assembly
                    ZStack {
                        Circle().fill(accent.opacity(dragging ? 0.12 : 0)).frame(width: 36, height: 36) // pulse ring
                        Circle()
                            .fill(RadialGradient(colors: [Forge.frost, accent.opacity(0.8)], center: .center, startRadius: 0, endRadius: 11))
                            .frame(width: dragging ? 20 : 15, height: dragging ? 20 : 15)
                            .shadow(color: accent.opacity(0.55), radius: dragging ? 14 : 6)
                            .overlay(Circle().strokeBorder(Forge.frost.opacity(0.25), lineWidth: 0.5))
                    }
                    .position(x: x, y: 2)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7), value: dragging)
                    .animation(.spring(response: 0.12, dampingFraction: 0.85), value: x)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                dragging = true
                                let frac = max(0, min(1, v.location.x / w))
                                let snapped = (Int(frac * 1440) / step) * step
                                if snapped != minutes { haptic.impactOccurred(intensity: 0.3); minutes = snapped }
                            }
                            .onEnded { _ in
                                dragging = false
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.45)
                            }
                    )
                }
                .frame(height: 4)
            }
            .frame(height: 32)
            .background(GeometryReader { trackGeo in
                Color.clear.preference(
                    key: SliderFramesKey.self,
                    value: sessionID != nil ? [SliderFrameInfo(sessionID: sessionID!, isStartSlider: isStartSlider, frame: trackGeo.frame(in: .global))] : []
                )
            })

            // ── Hour Labels ──
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    if h > 0 { Spacer() }
                    Text("\(h)h")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Forge.steel.opacity(0.35))
                    if h < 24 { Spacer() }
                }
            }
        }
        .padding(.horizontal, 2)
        .onAppear { haptic.prepare() }
    }
}

#Preview {
    ZStack {
        Forge.obsidian.ignoresSafeArea()
        VStack(spacing: 32) {
            NeonTimeSlider(label: "FROM", minutes: .constant(420), accent: Forge.cipher)
            NeonTimeSlider(label: "TO", minutes: .constant(960), accent: Forge.arcane)
        }.padding(44)
    }.preferredColorScheme(.dark)
}
