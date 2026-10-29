import SwiftUI

/// Reusable month grid used by Goals, Finance, Appointments and Gratitude.
struct MonthCalendarView: View {
    @Binding var month: Date
    var selected: Date?
    var accent: Color = AZ.violetLight
    /// Days that have activity.
    var marked: (Date) -> Bool
    var onSelect: (Date) -> Void

    private let cal = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var days: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let count = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start) - 1
        var result: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in 0..<count {
            result.append(cal.date(byAdding: .day, value: d, to: interval.start))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36)
                        .background(accent.opacity(0.12), in: .circle)
                }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 36)
                        .background(accent.opacity(0.12), in: .circle)
                }
            }
            .foregroundStyle(accent)
            .buttonStyle(.squish(0.9))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                    Text(d).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.45))
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isToday = cal.isDateInToday(day)
        let has = marked(day)
        return Button {
            Haptics.select()
            onSelect(day)
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.subheadline.weight(isToday || has ? .bold : .regular))
                .foregroundStyle(has || isSelected ? .white : .white.opacity(isToday ? 1 : 0.75))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.38) : (has ? accent.opacity(0.19) : .clear))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(has ? accent : (isToday ? .white.opacity(0.5) : .clear), lineWidth: has ? 1.5 : 1)
                }
        }
        .buttonStyle(.squish(0.9))
    }

    private func shift(_ value: Int) {
        Haptics.select()
        withAnimation(.snappy) {
            month = cal.date(byAdding: .month, value: value, to: month) ?? month
        }
    }
}
