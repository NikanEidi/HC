//
//  TimeInputTableView.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  BACK CARD — Timesheet Session Editor                         ║
//  ║                                                               ║
//  ║  Dynamic session rows with dual NeonTimeSliders (FROM/TO).    ║
//  ║  Each row displays:                                           ║
//  ║    • Zero-padded index badge                                  ║
//  ║    • Color-coded date (weekday=Arcane, weekend=Crimson)        ║
//  ║    • Duration gradient readout                                ║
//  ║    • Inline FROM/TO time sliders with haptic snapping          ║
//  ║                                                               ║
//  ║  Header COPY button exports the session report to clipboard   ║
//  ║  with glow effect driven by the gesture hover system.         ║
//  ║  Reports geometry frames for gesture hit-testing.             ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

/// The back face of the flip card. Renders a scrollable list of
/// work sessions with inline time adjustment sliders and a
/// gradient total bar at the bottom.
struct TimeInputTableView: View {

    /// Reference to the shared ViewModel for session data and report generation.
    @Bindable var viewModel: TrackerViewModel

    /// When true, the COPY button renders with an intensified Jade glow,
    /// pulsing border, and 1.05x scale — driven by gesture hover proximity.
    var isCopyButtonGlowing: Bool = false

    /// External binding for programmatic scroll. When set, the list scrolls
    /// to the specified session index using an interactive spring animation.
    @Binding var scrollTargetIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 14)
            dividerLine.padding(.horizontal, 24)
            if viewModel.sessions.isEmpty { empty } else { list }
            if !viewModel.sessions.isEmpty { total.padding(.horizontal, 22).padding(.bottom, 20) }
        }
        .glassCard(radius: 24, glow: Forge.cipher)
    }

    // MARK: - Header (Title + COPY Button)

    /// Title bar with entry count and the clipboard COPY button.
    /// The COPY button reports its frame via `CopyButtonFrameKey` and
    /// `TappableFramesKey` for gesture system hit-testing.
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(">>")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Forge.arcane.opacity(0.5))
                    Text("TIMESHEET")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(Forge.frost.opacity(0.9)).tracking(4)
                }
                Text("\(viewModel.sessions.count) entr\(viewModel.sessions.count == 1 ? "y" : "ies")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Forge.steel.opacity(0.5)).tracking(1)
            }
            Spacer()
            Button {
                ClipboardManager.copy(viewModel.generateReportString())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 11))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Forge.jade)
                        .symbolEffect(.bounce, value: isCopyButtonGlowing)
                    Text("COPY").font(.system(size: 10, weight: .black, design: .monospaced)).tracking(2)
                }
                .foregroundColor(Forge.jade)
                .frame(minWidth: 64, minHeight: 28)
                .background(
                    Capsule().fill(Forge.jade.opacity(isCopyButtonGlowing ? 0.12 : 0.05))
                        .overlay(Capsule().strokeBorder(Forge.jade.opacity(isCopyButtonGlowing ? 0.35 : 0.12),
                                                        lineWidth: isCopyButtonGlowing ? 1.2 : 0.5)))
            }
            .hoverEffect(.lift)
            .shadow(color: isCopyButtonGlowing ? Forge.jade.opacity(0.5) : .clear, radius: isCopyButtonGlowing ? 14 : 0)
            .scaleEffect(isCopyButtonGlowing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isCopyButtonGlowing)
            .background(GeometryReader { geo in
                Color.clear.preference(key: CopyButtonFrameKey.self, value: geo.frame(in: .global))
            })
            .reportTappableFrame(id: "copyBtn")
        }
    }

    // MARK: - Scrollable Session List

    /// Vertical scroll view of session rows wrapped in a `ScrollViewReader`
    /// for programmatic scroll-to-index from the gesture system.
    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { i, s in
                        row(s, idx: i)
                            .onAppear {
                                scrollTargetIndex = i
                            }
                    }
                }.padding(.horizontal, 22).padding(.vertical, 16)
            }
            .onChange(of: scrollTargetIndex) { _, newIndex in
                if let newIndex {
                    if newIndex >= 0 && newIndex < viewModel.sessions.count {
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.90)) {
                            proxy.scrollTo(viewModel.sessions[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Individual Session Row

    /// Renders a single session entry with index badge, date, duration,
    /// and dual FROM/TO `NeonTimeSlider` instances bound to the ViewModel
    /// via its `startMinutesBinding` / `endMinutesBinding` factories.
    private func row(_ s: WorkSession, idx: Int) -> some View {
        let startB = viewModel.startMinutesBinding(for: s.id)
        let endB = viewModel.endMinutesBinding(for: s.id)
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d MMM"; return f }()
        let wknd = viewModel.isWeekend(s.date)

        return VStack(spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", idx + 1))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Forge.steel.opacity(0.3))
                        .frame(minWidth: 22, minHeight: 18)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Forge.frost.opacity(0.025)))

                    Circle().fill(wknd ? Forge.crimson : Forge.arcane).frame(width: 7, height: 7)
                        .shadow(color: (wknd ? Forge.crimson : Forge.arcane).opacity(0.45), radius: 4)

                    Text(df.string(from: s.date).uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(Forge.frost.opacity(0.9)).tracking(1.5)
                }
                Spacer()
                Text(s.durationString)
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(LinearGradient(colors: [Forge.cipher, Forge.arcane], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: Forge.cipher.opacity(0.30), radius: 8)
            }

            NeonTimeSlider(label: "FROM", minutes: Binding(get: { startB.get() }, set: { startB.set($0) }), accent: Forge.cipher, sessionID: s.id, isStartSlider: true)

            NeonTimeSlider(label: "TO", minutes: Binding(get: { endB.get() }, set: { endB.set($0) }), accent: Forge.arcane, sessionID: s.id, isStartSlider: false)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Forge.frost.opacity(0.012))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Forge.frost.opacity(0.035), Forge.frost.opacity(0.008)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
        )
    }

    // MARK: - Empty State Placeholder

    /// Displayed when no sessions exist. Guides the user to flip back
    /// to the calendar view and select dates.
    private var empty: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("---").font(.system(size: 30, weight: .ultraLight, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.12))
            Text("NO SESSIONS").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.2)).tracking(4)
            Text("Flip to calendar --> select dates")
                .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.1))
            Spacer()
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: - Gradient Total Bar

    /// Sticky footer showing cumulative hours across all sessions.
    /// Uses a Cipher→Arcane gradient for the large numeric readout.
    private var total: some View {
        HStack {
            HStack(spacing: 6) {
                Text(">>>").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(Forge.cipher.opacity(0.35))
                Text("TOTAL HOURS").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.5)).tracking(3)
            }
            Spacer()
            Text(viewModel.calculateTotalHours())
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(LinearGradient(colors: [Forge.cipher, Forge.arcane], startPoint: .leading, endPoint: .trailing))
                .shadow(color: Forge.cipher.opacity(0.25), radius: 14)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Forge.frost.opacity(0.015))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Forge.cipher.opacity(0.10), Forge.arcane.opacity(0.10)],
                                                 startPoint: .leading, endPoint: .trailing), lineWidth: 0.5)))
    }

    // MARK: - Gradient Divider

    /// Subtle horizontal gradient line separating header from content.
    private var dividerLine: some View {
        Rectangle().fill(LinearGradient(colors: [Forge.arcane.opacity(0.0), Forge.arcane.opacity(0.12), Forge.cipher.opacity(0.0)],
                                         startPoint: .leading, endPoint: .trailing)).frame(height: 0.5)
    }
}

#Preview {
    ZStack {
        GlassmorphismBG()
        TimeInputTableView(viewModel: {
            let vm = TrackerViewModel()
            for i in 0..<3 { if let d = Calendar.current.date(byAdding: .day, value: i, to: Date()) { vm.toggleDate(d) } }
            return vm
        }(), scrollTargetIndex: .constant(nil)).frame(width: 460).padding()
    }.preferredColorScheme(.dark)
}
