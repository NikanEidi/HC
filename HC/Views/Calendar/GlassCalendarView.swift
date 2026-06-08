//
//  GlassCalendarView.swift
//  HC
//
//  Front card — Neo-Tokyo glass calendar with multi-date selection.
//  Weekends glow Laser Red/Gold. Weekday selections glow Neon Purple/Cyan.
//

import SwiftUI

struct GlassCalendarView: View {
    @Bindable var viewModel: TrackerViewModel
    @State private var hoveredDate: Date? = nil

    private let weekdayHeaders = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // ── Header: Month Navigation ──
            monthNavigation
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            // ── Weekday Labels ──
            weekdayRow
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 20)

            // ── Day Grid ──
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(viewModel.daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)

            // ── Selection Count ──
            if !viewModel.selectedDates.isEmpty {
                selectionBadge
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .glassCard(cornerRadius: 28)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedDates.count)
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button(action: { viewModel.previousMonth() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(NeoTokyo.neonCyan)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(NeoTokyo.neonCyan.opacity(0.08))
                    )
            }

            Spacer()

            Text(viewModel.monthYearString.uppercased())
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .tracking(3)

            Spacer()

            Button(action: { viewModel.nextMonth() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(NeoTokyo.neonCyan)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(NeoTokyo.neonCyan.opacity(0.08))
                    )
            }
        }
    }

    // MARK: - Weekday Headers

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayHeaders, id: \.self) { day in
                Text(day)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        (day == "SAT" || day == "SUN")
                        ? NeoTokyo.laserRed.opacity(0.7)
                        : .white.opacity(0.35)
                    )
                    .tracking(1.2)
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

        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: date)

        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.toggleDate(date)
        }) {
            ZStack {
                // ── Background ──
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cellBackground(isSelected: isSelected, isWeekend: isWeekend, isHovered: isHovered))

                // ── Selection Ring ──
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isWeekend
                            ? LinearGradient(colors: [NeoTokyo.laserRed, NeoTokyo.laserGold], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [NeoTokyo.neonPurple, NeoTokyo.neonCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                        .shadow(
                            color: isWeekend ? NeoTokyo.laserRed.opacity(0.4) : NeoTokyo.neonPurple.opacity(0.4),
                            radius: 8
                        )
                }

                // ── Today indicator ──
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NeoTokyo.terminalGreen.opacity(0.4), lineWidth: 1)
                }

                // ── Day Number ──
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundColor(dayTextColor(isSelected: isSelected, isWeekend: isWeekend, isToday: isToday))
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredDate = hovering ? date : nil
            }
        }
    }

    // MARK: - Helpers

    private func cellBackground(isSelected: Bool, isWeekend: Bool, isHovered: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                isWeekend
                ? NeoTokyo.laserRed.opacity(0.12)
                : NeoTokyo.neonPurple.opacity(0.10)
            )
        }
        if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.04))
        }
        return AnyShapeStyle(Color.clear)
    }

    private func dayTextColor(isSelected: Bool, isWeekend: Bool, isToday: Bool) -> Color {
        if isSelected {
            return isWeekend ? NeoTokyo.laserGold : NeoTokyo.neonCyan
        }
        if isToday {
            return NeoTokyo.terminalGreen
        }
        if isWeekend {
            return NeoTokyo.laserRed.opacity(0.5)
        }
        return .white.opacity(0.65)
    }

    // MARK: - Selection Badge

    private var selectionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 11))

            Text("\(viewModel.selectedDates.count) day\(viewModel.selectedDates.count > 1 ? "s" : "") selected")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(NeoTokyo.neonCyan.opacity(0.7))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(NeoTokyo.neonCyan.opacity(0.06))
                .overlay(
                    Capsule()
                        .strokeBorder(NeoTokyo.neonCyan.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    ZStack {
        GlassmorphismBG()
        GlassCalendarView(viewModel: TrackerViewModel())
            .frame(width: 380)
            .padding()
    }
    .preferredColorScheme(.dark)
}
