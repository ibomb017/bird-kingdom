import SwiftUI

/// 开屏日历选择视图
struct SplashCalendarView: View {
    @StateObject private var splashService = SplashService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var isLoading = true
    @State private var showUploadView = false
    @State private var reserveResponse: SplashService.ReserveResponse?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isReserving = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        VStack(spacing: 0) {
            // 月份选择器
            monthSelector
            
            // 星期标题
            weekdayHeader
            
            // 日历网格
            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else {
                calendarGrid
            }
            
            Spacer()
            
            // 选中日期信息
            if let date = selectedDate {
                selectedDateInfo(date)
            }
            
            // 购买按钮
            purchaseButton
        }
        .padding()
        .themedBackground()
        .navigationTitle(NSLocalizedString("选择展示日期", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(primaryColor.opacity(0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(primaryColor)
        .onAppear {
            loadQuotas()
        }
        .alert(L10n.hintTitle, isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.unknownError)
        }
        .navigationDestination(isPresented: $showUploadView) {
            if let response = reserveResponse {
                SplashUploadView(reserveResponse: response)
                    .hidesTabBar()
            }
        }
    }
    
    // MARK: - 月份选择器
    
    private var monthSelector: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack ? .primary : .gray)
            }
            .disabled(!canGoBack)
            
            Spacer()
            
            Text(monthYearString)
                .font(.headline)
            
            Spacer()
            
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(canGoForward ? .primary : .gray)
            }
            .disabled(!canGoForward)
        }
        .padding(.vertical, 12)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: currentMonth)
    }
    
    private var canGoBack: Bool {
        let thisMonth = calendar.startOfMonth(for: Date())
        let displayMonth = calendar.startOfMonth(for: currentMonth)
        return displayMonth > thisMonth
    }
    
    private var canGoForward: Bool {
        let maxMonth = calendar.date(byAdding: .month, value: 12, to: Date())!
        let displayMonth = calendar.startOfMonth(for: currentMonth)
        return displayMonth < calendar.startOfMonth(for: maxMonth)
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            loadQuotas()
        }
    }
    
    // MARK: - 星期标题
    
    private var weekdayHeader: some View {
        HStack {
            ForEach([NSLocalizedString("日", comment: ""), NSLocalizedString("一", comment: ""), NSLocalizedString("二", comment: ""), NSLocalizedString("三", comment: ""), NSLocalizedString("四", comment: ""), NSLocalizedString("五", comment: ""), NSLocalizedString("六", comment: "")], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 日历网格
    
    private var calendarGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if let date = day {
                    SplashDayCell(
                        date: date,
                        quota: getQuota(for: date),
                        isSelected: selectedDate == date,
                        isSelectable: isDateSelectable(date),
                        primaryColor: primaryColor
                    ) {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
    }
    
    private func daysInMonth() -> [Date?] {
        let startOfMonth = calendar.startOfMonth(for: currentMonth)
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        
        // 计算月初是星期几
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let paddingDays = weekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: paddingDays)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func getQuota(for date: Date) -> SplashService.QuotaInfo? {
        let dateStr = dateFormatter.string(from: date)
        return splashService.quotas[dateStr]
    }
    
    private func isDateSelectable(_ date: Date) -> Bool {
        let tomorrow = calendar.startOfDay(for: Date().addingTimeInterval(86400))
        let maxDate = calendar.date(byAdding: .day, value: 365, to: Date())!
        
        guard date >= tomorrow && date <= maxDate else { return false }
        
        if let quota = getQuota(for: date) {
            return quota.available > 0
        }
        
        return true // 无数据时默认可选
    }
    
    // MARK: - 选中日期信息
    
    private func selectedDateInfo(_ date: Date) -> some View {
        let dateStr = dateFormatter.string(from: date)
        let quota = splashService.quotas[dateStr]
        
        return VStack(spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("已选择", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dateStr)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(NSLocalizedString("剩余名额", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(quota?.available ?? 10) / 10")
                        .font(.headline)
                        .foregroundColor(primaryColor)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 购买按钮
    
    private var purchaseButton: some View {
        Button {
            reserveSlot()
        } label: {
            HStack {
                if isReserving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("立即购买 ¥\(SplashService.shared.currentPrice.formatted(.number.precision(.fractionLength(0))))")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedDate != nil && !isReserving ? primaryColor : Color(uiColor: .systemGray3))
            .cornerRadius(14)
        }
        .disabled(selectedDate == nil || isReserving)
    }
    
    // MARK: - 加载名额
    
    private func loadQuotas() {
        isLoading = true
        
        let startOfMonth = calendar.startOfMonth(for: currentMonth)
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!.addingTimeInterval(-86400)
        
        Task {
            do {
                try await splashService.fetchQuotas(startDate: startOfMonth, endDate: endOfMonth)
            } catch {
                print("加载名额失败: \(error)")
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - 预占名额
    
    private func reserveSlot() {
        guard let date = selectedDate else { return }
        guard !isReserving else { return }  // ✅ 防重复点击：如果正在预占中，直接返回
        
        isReserving = true
        
        Task {
            do {
                let response = try await splashService.reserveSlot(displayDate: date)
                await MainActor.run {
                    reserveResponse = response
                    showUploadView = true
                    isReserving = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isReserving = false
                }
            }
        }
    }
}

// MARK: - 日期单元格

struct SplashDayCell: View {
    let date: Date
    let quota: SplashService.QuotaInfo?
    let isSelected: Bool
    let isSelectable: Bool
    let primaryColor: Color
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var isPast: Bool {
        date < calendar.startOfDay(for: Date().addingTimeInterval(86400))
    }
    
    private var availableSlots: Int {
        quota?.available ?? 10
    }
    
    private var isSoldOut: Bool {
        availableSlots <= 0
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                
                if !isPast {
                    if isSoldOut {
                        Text(NSLocalizedString("已满", comment: ""))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    } else {
                        Text("剩\(availableSlots)")
                            .font(.system(size: 8))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : primaryColor.opacity(0.8))
                    }
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(10)
        }
        .disabled(!isSelectable)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        }
        if isPast || isSoldOut {
            return Color(uiColor: .tertiaryLabel)
        }
        return .primary
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return primaryColor
        }
        if isToday {
            return primaryColor.opacity(0.1)
        }
        if isPast || isSoldOut {
            return Color(uiColor: .tertiarySystemFill)
        }
        return Color(uiColor: .secondarySystemFill)
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    NavigationStack {
        SplashCalendarView()
    }
}
