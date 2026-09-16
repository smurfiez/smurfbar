import SwiftUI
import AppKit
import Combine

/// Interactive calendar & clock popover view.
struct CalendarFlyoutView: View {
    let onClose: () -> Void

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var currentTime: Date = Date()

    private let calendar = Calendar.current
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            // Header: Digital Time & Full Date
            VStack(spacing: 4) {
                Text(timeString(from: currentTime))
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundColor(.primary)

                Text(fullDateString(from: currentTime))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 14)

            Divider()
                .padding(.horizontal, 8)

            // Month navigation
            HStack {
                Text(monthYearString(from: displayedMonth))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 6) {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button("Today") {
                        displayedMonth = Date()
                        selectedDate = Date()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Days of week header
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            // Calendar month grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(daysInMonth(for: displayedMonth), id: \.self) { date in
                    dayCell(for: date)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 320)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 16, y: -6)
        .onReceive(timer) { date in
            currentTime = date
        }
    }

    // MARK: - Day Cell

    private func dayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let dayNumber = calendar.component(.day, from: date)

        return Button(action: {
            selectedDate = date
        }) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                } else if isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isToday ? .white :
                        isCurrentMonth ? .primary : .secondary.opacity(0.4)
                    )
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return symbols
    }

    private func daysInMonth(for month: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingDays = firstWeekday - calendar.firstWeekday
        let adjustedLeading = (leadingDays + 7) % 7

        var dates: [Date] = []

        // Leading days from previous month
        if adjustedLeading > 0 {
            for offset in (1...adjustedLeading).reversed() {
                if let date = calendar.date(byAdding: .day, value: -offset, to: firstDayOfMonth) {
                    dates.append(date)
                }
            }
        }

        // Days in current month
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31
        for day in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDayOfMonth) {
                dates.append(date)
            }
        }

        // Trailing days from next month to complete 6 rows (42 days)
        while dates.count < 42 {
            if let last = dates.last, let next = calendar.date(byAdding: .day, value: 1, to: last) {
                dates.append(next)
            } else {
                break
            }
        }

        return dates
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }

    private func fullDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
