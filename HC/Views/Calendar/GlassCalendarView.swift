//
//  GlassCalendarView.swift
//  HC
//
//  Front card — Premium Neo-Tokyo glass calendar.
//  Weekends: Laser Red/Gold. Weekdays: Neon Purple/Cyan.
//  Apple Pencil hover support, no emoji.
//

import SwiftUI

struct GlassCalendarView: View {
    @Bindable var viewModel: TrackerViewModel
    @State private var hoveredDate: Date? = nil
    @State private var headerGlow: CGFloat = 0

    private let weekdayHeaders = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            calendarHeader
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 14)

            weekdayRow
                .padding(.horizontal, 18)
                .padding(.bottom, 10)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [NeoTokyo.neonPurple.opacity(0.0), NeoTokyo.neonCyan.opacity(0.15), NeoTokyo.neonPurple.opacity(0.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .padding(.horizontal, 22)

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(viewModel.daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 18)

            if !viewModel.selectedDates.isEmpty {
                selectionBadge
                    .padding(.bottom, 18)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .glassCard(cornerRadius: 26, glowColor: NeoTokyo.neonPurple)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.selectedDates.count)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                headerGlow = 1
            }
        }
    }

    // MARK: - Calendar Header

    private var calendarHeader: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.previousMonth()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(NeoTokyo.neonCyan)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(NeoTokyo.neonCyan.opacity(0.06))
                            .overlay(Circle().strokeBorder(NeoTokyo.neonCyan.opacity(0.12), lineWidth: 0.5))
                    )
                    .hoverEffect(.lift)
            }

            Spacer()

            VStack(spacing: 3) {
                Text(viewModel.monthYearString.uppercased())
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(4)
                    .shadow(color: NeoTokyo.neonCyan.opacity(0.3 + headerGlow * 0.2), radius: 8)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [NeoTokyo.neonPurple.opacity(0.0), NeoTokyo.neonCyan.opacity(0.4 + headerGlow * 0.3), NeoTokyo.neonPurple.opacity(0.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 100, height: 1)
            }

            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.nextMonth()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(NeoTokyo.neonCyan)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(NeoTokyo.neonCyan.opacity(0.06))
                            .overlay(Circle().strokeBorder(NeoTokyo.neonCyan.opacity(0.12), lineWidth: 0.5))
                    )
                    .hoverEffect(.lift)
            }
        }
    }

    // MARK: - Weekday Row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayHeaders, id: \.self) { day in
                let isWknd = (day == "SAT" || day == "SUN")
                Text(day)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(isWknd ? NeoTokyo.laserRed.opacity(0.6) : .white.opacity(0.3))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isSelected = viewModel.isSelected(date)
        let isWeekend = viewModel.isWeekend(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isHovered = hoveredDate == date
        let dayNumber = Calendar.current.component(.day, from: date)

        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.toggleDate(date)
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(cellBG(isSelected: isSelected, isWeekend: isWeekend, isHovered: isHovered))

                // Selection border with glow
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            isWeekend
                            ? LinearGradient(colors: [NeoTokyo.laserRed, NeoTokyo.laserGold], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [NeoTokyo.neonPurple, NeoTokyo.neonCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                        .shadow(color: isWeekend ? NeoTokyo.laserRed.opacity(0.35) : NeoTokyo.neonPurple.opacity(0.35), radius: 10)
                }

                // Today: subtle thin bottom line, NOT green text
                if isToday && !isSelected {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(NeoTokyo.neonCyan.opacity(0.35))
                            .frame(width: 16, height: 1.5)
                            .clipShape(Capsule())
                            .padding(.bottom, 6)
                    }
                }

                // Day number + selection dot
                VStack(spacing: 2) {
                    Text("\(dayNumber)")
                        .font(.system(size: 16, weight: isSelected ? .black : .semibold, design: .monospaced))
                        .foregroundColor(dayColor(isSelected: isSelected, isWeekend: isWeekend))

                    if isSelected {
                        Circle()
                            .fill(isWeekend ? NeoTokyo.laserGold : NeoTokyo.neonCyan)
                            .frame(width: 4, height: 4)
                            .shadow(color: (isWeekend ? NeoTokyo.laserGold : NeoTokyo.neonCyan).opacity(0.6), radius: 3)
                    }
                }
            }
            .frame(height: 52)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .onHover { hov in
            withAnimation(.easeOut(duration: 0.12)) { hoveredDate = hov ? date : nil }
        }
    }

    // MARK: - Helpers

    private func cellBG(isSelected: Bool, isWeekend: Bool, isHovered: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(isWeekend ? NeoTokyo.laserRed.opacity(0.14) : NeoTokyo.neonPurple.opacity(0.12))
        }
        if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.035))
        }
        return AnyShapeStyle(Color.white.opacity(0.01))
    }

    private func dayColor(isSelected: Bool, isWeekend: Bool) -> Color {
        if isSelected { return isWeekend ? NeoTokyo.laserGold : NeoTokyo.neonCyan }
        if isWeekend { return NeoTokyo.laserRed.opacity(0.45) }
        return .white.opacity(0.6)
    }

    // MARK: - Selection Badge

    private var selectionBadge: some View {
        HStack(spacing: 8) {
            Text("[")
                .foregroundColor(NeoTokyo.neonCyan.opacity(0.3))
            +
            Text("\(viewModel.selectedDates.count)")
                .foregroundColor(NeoTokyo.neonCyan)
            +
            Text("]")
                .foregroundColor(NeoTokyo.neonCyan.opacity(0.3))

            Text(viewModel.selectedDates.count > 1 ? "DAYS SELECTED" : "DAY SELECTED")
                .foregroundColor(.white.opacity(0.35))
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .tracking(1.5)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(NeoTokyo.neonCyan.opacity(0.04))
                .overlay(Capsule().strokeBorder(NeoTokyo.neonCyan.opacity(0.12), lineWidth: 0.5))
        )
    }
}

#Preview {
    ZStack {
        GlassmorphismBG()
        GlassCalendarView(viewModel: TrackerViewModel())
            .frame(width: 420).padding()
    }
    .preferredColorScheme(.dark)
}
