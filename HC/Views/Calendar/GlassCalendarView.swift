//
//  GlassCalendarView.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  FRONT CARD — Premium Glass Calendar                          ║
//  ║                                                               ║
//  ║  Renders a month-view grid with multi-select capability.      ║
//  ║  Color coding:                                                ║
//  ║    • Weekday selections: Arcane/Cipher gradient border         ║
//  ║    • Weekend selections: Crimson/Ember gradient border         ║
//  ║    • Today: Cyan underline accent                             ║
//  ║                                                               ║
//  ║  Supports Apple Pencil hover + air-gesture hover glow on      ║
//  ║  every interactive cell. Reports geometry frames for the       ║
//  ║  gesture hit-testing pipeline via PreferenceKeys.              ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

/// The front face of the flip card. Renders a month-view calendar grid
/// with multi-select capability, weekend/weekday color coding, and
/// animated micro-interactions including gesture-driven hover glow.
struct GlassCalendarView: View {

    /// Reference to the shared ViewModel for date selection and navigation.
    @Bindable var viewModel: TrackerViewModel

    /// Currently hovered date from the air-gesture system (passed by parent).
    var gestureHoveredDate: Date? = nil

    /// Currently hovered date from Apple Pencil hover events.
    @State private var hovered: Date? = nil

    /// Breathing pulse animation value (0–1) for subtle title glow.
    @State private var pulse: CGFloat = 0

    /// Fixed weekday header labels (ISO 8601: Monday-first).
    private let headers = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    /// 7-column flexible grid layout for the calendar days.
    private let grid = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            navigation.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
            weekRow.padding(.horizontal, 20).padding(.bottom, 10)
            dividerLine.padding(.horizontal, 24)
            dayGrid
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 20)
            
            badge.padding(.bottom, 20)
                .opacity(viewModel.selectedDates.isEmpty ? 0 : 1)
                .scaleEffect(viewModel.selectedDates.isEmpty ? 0.85 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.selectedDates.isEmpty)
        }
        .glassCard(radius: 24, glow: Forge.arcane)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.selectedDates.count)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { pulse = 1 }
        }
    }

    // MARK: - Month Navigation Bar

    /// Left/right chevrons + centered month-year title with animated glow underline.
    private var navigation: some View {
        HStack {
            navButton(icon: "chevron.left") { viewModel.previousMonth() }
                .reportTappableFrame(id: "prevMonth")
            Spacer()
            VStack(spacing: 4) {
                Text(viewModel.monthYearString.uppercased())
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(Forge.frost.opacity(0.9)).tracking(5)
                    .shadow(color: Forge.cipher.opacity(0.25 + pulse * 0.2), radius: 10)
                Capsule()
                    .fill(LinearGradient(colors: [Forge.arcane.opacity(0.0), Forge.cipher.opacity(0.3 + pulse * 0.25), Forge.arcane.opacity(0.0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 90, height: 1.5)
            }
            Spacer()
            navButton(icon: "chevron.right") { viewModel.nextMonth() }
                .reportTappableFrame(id: "nextMonth")
        }
    }

    /// Creates a circular chevron navigation button with haptic feedback.
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); action() }) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Forge.cipher)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Forge.cipher.opacity(0.05))
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [Forge.cipher.opacity(0.35), Forge.cipher.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6))
                    .shadow(color: Forge.cipher.opacity(0.10), radius: 8))
        }.hoverEffect(.lift)
    }

    // MARK: - Weekday Header Row

    /// Horizontal row of MON–SUN labels. Weekend columns use crimson tint.
    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(headers, id: \.self) { d in
                Text(d)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor((d == "SAT" || d == "SUN") ? Forge.crimson.opacity(0.55) : Forge.steel.opacity(0.45))
                    .tracking(1.8).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Cell Grid

    /// 7-column LazyVGrid of interactive day cells with geometry reporting
    /// for the air-gesture hit-testing system.
    private var dayGrid: some View {
        let days = viewModel.daysInMonth
        let rowCount = (days.count + 6) / 7
        return VStack(spacing: 7) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { colIndex in
                        let index = rowIndex * 7 + colIndex
                        if index < days.count {
                            if let date = days[index] {
                                cell(date, index: index)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                        }
                    }
                }
            }
        }
        .background(GeometryReader { geo in
            let w = (geo.size.width - 36) / 7.0
            let frames = (0..<days.count).map { i -> TappableElement in
                let r = i / 7
                let c = i % 7
                let rect = CGRect(
                    x: geo.frame(in: .global).minX + CGFloat(c) * (w + 6),
                    y: geo.frame(in: .global).minY + CGFloat(r) * 61, // 54 height + 7 spacing
                    width: w,
                    height: 54
                )
                return TappableElement(id: "date_\(i)", frame: rect)
            }
            Color.clear.preference(key: TappableFramesKey.self, value: frames)
        })
    }

    // MARK: - Individual Day Cell

    /// Renders a single day cell with 6 visual states:
    /// 1. Default — near-transparent fill
    /// 2. Selected weekday — Arcane/Cipher gradient border + Cipher text
    /// 3. Selected weekend — Crimson/Ember gradient border + Ember text
    /// 4. Today (unselected) — Cyan underline capsule
    /// 5. Gesture-hovered — Cipher border glow + 1.02x scale
    /// 6. Pencil-hovered — subtle white tint background
    @ViewBuilder private func cell(_ date: Date, index: Int) -> some View {
        let sel = viewModel.isSelected(date)
        let wknd = viewModel.isWeekend(date)
        let today = Calendar.current.isDateInToday(date)
        let day = Calendar.current.component(.day, from: date)
        let gh = gestureHoveredDate != nil && Calendar.current.isDate(gestureHoveredDate!, inSameDayAs: date)

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.toggleDate(date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(sel ? (wknd ? Forge.crimson.opacity(0.12) : Forge.arcane.opacity(0.10))
                          : ((hovered == date || gh) ? Color.white.opacity(0.025) : Color.white.opacity(0.008)))

                if sel {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            wknd ? LinearGradient(colors: [Forge.crimson, Forge.ember], startPoint: .topLeading, endPoint: .bottomTrailing)
                                 : LinearGradient(colors: [Forge.arcane, Forge.cipher], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.4)
                        .shadow(color: (wknd ? Forge.crimson : Forge.arcane).opacity(0.30), radius: 10)
                }

                if gh && !sel {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Forge.cipher.opacity(0.35), lineWidth: 1.2)
                        .shadow(color: Forge.cipher.opacity(0.45), radius: 12)
                }

                if today && !sel {
                    VStack { Spacer()
                        Capsule().fill(Forge.cipher.opacity(0.30)).frame(width: 14, height: 1.5).padding(.bottom, 7)
                    }
                }

                VStack(spacing: 3) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: sel ? .black : .medium, design: .monospaced))
                        .foregroundColor(sel ? (wknd ? Forge.ember : Forge.cipher)
                                         : (gh ? Forge.cipher.opacity(0.8) : (wknd ? Forge.crimson.opacity(0.40) : Forge.frost.opacity(0.55))))
                    if sel {
                        Circle().fill(wknd ? Forge.ember : Forge.cipher).frame(width: 4, height: 4)
                            .shadow(color: (wknd ? Forge.ember : Forge.cipher).opacity(0.5), radius: 3)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .scaleEffect(sel ? 1.03 : (gh ? 1.02 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: sel)
            .animation(.easeOut(duration: 0.15), value: gh)
        }
        .buttonStyle(.plain).hoverEffect(.highlight)
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovered = h ? date : nil } }
    }

    // MARK: - Gradient Divider

    /// Subtle horizontal gradient line separating the header from the grid.
    private var dividerLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Forge.arcane.opacity(0.0), Forge.cipher.opacity(0.12), Forge.arcane.opacity(0.0)],
                                  startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.5)
    }

    // MARK: - Selection Count Badge

    /// Animated capsule badge showing "[N] DAY(S)" selected count.
    /// Enters with scale+opacity transition, exits with opacity fade.
    private var badge: some View {
        HStack(spacing: 6) {
            Text("[\(Text("\(viewModel.selectedDates.count)").foregroundColor(Forge.cipher))]")
                .foregroundColor(Forge.cipher.opacity(0.3))
            Text(viewModel.selectedDates.count > 1 ? "DAYS" : "DAY")
                .foregroundColor(Forge.steel.opacity(0.5))
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(
            Capsule().fill(Forge.cipher.opacity(0.03))
                .overlay(Capsule().strokeBorder(Forge.cipher.opacity(0.08), lineWidth: 0.5)))
        .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
    }
}

#Preview {
    ZStack { GlassmorphismBG(); GlassCalendarView(viewModel: TrackerViewModel()).frame(width: 440).padding() }
        .preferredColorScheme(.dark)
}
