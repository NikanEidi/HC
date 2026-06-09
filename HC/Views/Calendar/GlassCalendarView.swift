//
//  GlassCalendarView.swift
//  HC
//
//  Front card — Premium glass calendar with Forge palette.
//  Weekends glow Ember/Crimson. Weekday selections glow Arcane/Cipher.
//  Apple Pencil hover + air-gesture hover on every interactive element.
//

import SwiftUI

/// The front face of the flip card. Renders a month-view calendar grid
/// with multi-select capability, weekend/weekday color coding, and
/// animated micro-interactions including gesture-driven hover glow.
struct GlassCalendarView: View {

    @Bindable var viewModel: TrackerViewModel
    var gestureHoveredDate: Date? = nil

    @State private var hovered: Date? = nil
    @State private var pulse: CGFloat = 0

    private let headers = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let grid = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            navigation.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
            weekRow.padding(.horizontal, 20).padding(.bottom, 10)
            dividerLine.padding(.horizontal, 24)
            dayGrid.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 20)
            if !viewModel.selectedDates.isEmpty { badge.padding(.bottom, 20) }
        }
        .glassCard(radius: 24, glow: Forge.arcane)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.selectedDates.count)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { pulse = 1 }
        }
    }

    // MARK: - Navigation

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

    // MARK: - Weekday Row

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

    // MARK: - Day Grid

    private var dayGrid: some View {
        LazyVGrid(columns: grid, spacing: 7) {
            ForEach(Array(viewModel.daysInMonth.enumerated()), id: \.offset) { index, date in
                if let date {
                    cell(date)
                        .reportTappableFrame(id: "date_\(index)")
                } else {
                    Color.clear.frame(height: 54)
                }
            }
        }
        .background(GeometryReader { geo in
            Color.clear.preference(key: CalendarGridFrameKey.self, value: geo.frame(in: .global))
        })
    }

    // MARK: - Day Cell

    @ViewBuilder private func cell(_ date: Date) -> some View {
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
            .frame(height: 54)
            .scaleEffect(sel ? 1.03 : (gh ? 1.02 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: sel)
            .animation(.easeOut(duration: 0.15), value: gh)
        }
        .buttonStyle(.plain).hoverEffect(.highlight)
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovered = h ? date : nil } }
    }

    // MARK: - Divider

    private var dividerLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Forge.arcane.opacity(0.0), Forge.cipher.opacity(0.12), Forge.arcane.opacity(0.0)],
                                  startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.5)
    }

    // MARK: - Badge

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
