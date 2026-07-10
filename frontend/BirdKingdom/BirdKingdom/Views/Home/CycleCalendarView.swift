import SwiftUI

/// 记录日历视图
struct CycleCalendarView: View {
    let cycles: [BirdCycleRecord]
    var showEggLaying: Bool = true
    @Binding var selectedDate: Date?  // 改为 Binding 以便父视图共享状态
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var currentMonth = Date()
    
    private var primaryColor: Color { themeManager.primaryColor }
    // 使用中国时区的日历，确保日期比较与解析使用相同的时区
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return cal
    }
    private let daysOfWeek = [NSLocalizedString("日", comment: ""), NSLocalizedString("一", comment: ""), NSLocalizedString("二", comment: ""), NSLocalizedString("三", comment: ""), NSLocalizedString("四", comment: ""), NSLocalizedString("五", comment: ""), NSLocalizedString("六", comment: "")]
    
    // 只过滤产蛋和洗澡记录
    private var filteredCycles: [BirdCycleRecord] {
        cycles
    }
    
    // 预过滤当前月相关的记录
    private var currentMonthCycles: [BirdCycleRecord] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        return filteredCycles.filter { cycle in
            return cycle.startDate >= monthInterval.start && cycle.startDate < monthInterval.end
        }
    }
    
    // 选中日期的记录
    private var selectedDateRecords: [BirdCycleRecord] {
        guard let date = selectedDate else { return [] }
        let startOfDate = calendar.startOfDay(for: date)
        return currentMonthCycles.filter {
            calendar.startOfDay(for: $0.startDate) == startOfDate
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 月份导航
            monthNavigator
            
            // 星期标题
            weekdayHeader
            
            // 日历网格
            calendarGrid
            
            // 图例
            legendView
            
            // 选中日期的记录详情
            if selectedDate != nil {
                selectedDateDetail
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - 月份导航
    
    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    previousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryColor)
            }
            
            Spacer()
            
            Text(monthYearString(currentMonth))
                .font(.headline)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    nextMonth()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryColor)
            }
        }
    }
    
    // MARK: - 星期标题
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - 日历网格
    
    private var calendarGrid: some View {
        let days = generateMonthDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    DayCellView(
                        date: date,
                        cycleTypes: getCycleTypes(for: date),
                        isToday: calendar.isDateInToday(date),
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        primaryColor: primaryColor
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedDate.map({ calendar.isDate($0, inSameDayAs: date) }) == true {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
    }
    
    // MARK: - 图例
    
    private var legendView: some View {
        HStack(spacing: 16) {
            if showEggLaying {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("产蛋", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text(NSLocalizedString("洗澡", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 选中日期详情
    
    private var selectedDateDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatSelectedDate())
                .font(.subheadline)
                .fontWeight(.medium)
            
            if selectedDateRecords.isEmpty {
                Text(NSLocalizedString("这天没有记录", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(selectedDateRecords) { record in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(record.cycleType == .EGG_LAYING ? Color.pink : Color.blue)
                            .frame(width: 8, height: 8)
                        
                        Text(record.cycleType.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if let notes = record.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.06))
        )
    }
    
    // MARK: - 辅助方法
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    private func formatSelectedDate() -> String {
        guard let date = selectedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("M月d日 EEEE", comment: "")
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        selectedDate = nil
    }
    
    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        selectedDate = nil
    }
    
    private func generateMonthDays() -> [Date?] {
        var days: [Date?] = []
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return days
        }
        
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func getCycleTypes(for date: Date) -> [CycleType] {
        var types: [CycleType] = []
        let startOfDate = calendar.startOfDay(for: date)
        
        for cycle in currentMonthCycles {
            let startOfCycleStart = calendar.startOfDay(for: cycle.startDate)
            if startOfDate == startOfCycleStart && !types.contains(cycle.cycleType) {
                types.append(cycle.cycleType)
            }
        }
        
        return types
    }
}

// MARK: - 日期单元格

struct DayCellView: View {
    let date: Date
    let cycleTypes: [CycleType]
    let isToday: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let primaryColor: Color
    
    // 使用中国时区的日历
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return cal
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 日期数字
            ZStack {
                if isToday || isSelected {
                    Circle()
                        .fill(isSelected ? primaryColor : primaryColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .regular))
                    .foregroundColor(textColor)
            }
            .frame(width: 32, height: 32)
            
            // 记录指示点
            HStack(spacing: 3) {
                if cycleTypes.isEmpty {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 5, height: 5)
                } else {
                    ForEach(cycleTypes, id: \.self) { type in
                        Circle()
                            .fill(type == .EGG_LAYING ? Color.pink : Color.blue)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(height: 5)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .gray.opacity(0.3)
        }
        if isSelected {
            return .white
        }
        if isToday {
            return primaryColor
        }
        return .primary
    }
}

#Preview {
    CycleCalendarView(cycles: [], selectedDate: .constant(nil))
        .padding()
}
