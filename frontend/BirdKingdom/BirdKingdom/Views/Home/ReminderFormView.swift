import SwiftUI

// 重复日期选择（类似苹果闹钟）
struct RepeatDays: Equatable {
    var sunday: Bool = false
    var monday: Bool = false
    var tuesday: Bool = false
    var wednesday: Bool = false
    var thursday: Bool = false
    var friday: Bool = false
    var saturday: Bool = false
    
    var isEmpty: Bool {
        !sunday && !monday && !tuesday && !wednesday && !thursday && !friday && !saturday
    }
    
    var isEveryday: Bool {
        sunday && monday && tuesday && wednesday && thursday && friday && saturday
    }
    
    var displayText: String {
        if isEmpty {
            return NSLocalizedString("永不", comment: "")
        }
        if isEveryday {
            return L10n.daily
        }
        
        var days: [String] = []
        if sunday { days.append(NSLocalizedString("周日", comment: "")) }
        if monday { days.append(NSLocalizedString("周一", comment: "")) }
        if tuesday { days.append(NSLocalizedString("周二", comment: "")) }
        if wednesday { days.append(NSLocalizedString("周三", comment: "")) }
        if thursday { days.append(NSLocalizedString("周四", comment: "")) }
        if friday { days.append(NSLocalizedString("周五", comment: "")) }
        if saturday { days.append(NSLocalizedString("周六", comment: "")) }
        
        return days.joined(separator: " ")
    }
    
    // 返回选中的 weekday 数组 (1=周日, 2=周一, ..., 7=周六)
    var selectedWeekdays: [Int] {
        var result: [Int] = []
        if sunday { result.append(1) }
        if monday { result.append(2) }
        if tuesday { result.append(3) }
        if wednesday { result.append(4) }
        if thursday { result.append(5) }
        if friday { result.append(6) }
        if saturday { result.append(7) }
        return result
    }
}

// 添加/编辑提醒的表单视图
struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var offlineService = OfflineDataService.shared
    
    let editingReminder: Reminder?  // nil 表示新建
    let onSave: (String, Date, RepeatDays) -> Void
    
    @State private var title: String = ""
    @State private var reminderTime: Date = Date()
    @State private var repeatDays: RepeatDays = RepeatDays()
    @State private var showOfflineAlert: Bool = false
    @State private var hasAttemptedSave: Bool = false  // P0 改进：记录是否尝试过保存
    @State private var scrollTarget: FormField? = nil  // P0 改进：用于滚动到未填写的表单项
    
    // 表单字段 ID
    private enum FormField: Hashable {
        case title
    }
    
    init(editingReminder: Reminder? = nil, onSave: @escaping (String, Date, RepeatDays) -> Void) {
        self.editingReminder = editingReminder
        self.onSave = onSave
        _title = State(initialValue: editingReminder?.title ?? "")
        // 尝试从 timeDescription 解析时间和重复日期
        if let reminder = editingReminder {
            _reminderTime = State(initialValue: Self.parseTime(from: reminder.timeDescription) ?? Date())
            _repeatDays = State(initialValue: Self.parseRepeatDays(from: reminder.timeDescription))
        }
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && offlineService.isOnline }
    
    var body: some View {
        VStack(spacing: 0) {
            // P2-03: 离线状态提示（保留但简化样式）
            if !offlineService.isOnline {
                Text(NSLocalizedString("当前处于离线状态，无法保存提醒", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            
            ScrollViewReader { scrollProxy in
                Form {
                    Section {
                        // 提醒内容：标签 + 自定义 placeholder
                        HStack {
                            Text(NSLocalizedString("提醒内容", comment: ""))
                                .foregroundColor(.primary)
                            ZStack(alignment: .leading) {
                                if title.isEmpty {
                                    Text(NSLocalizedString("* 例如：喂食、小鸟体检、清洁鸟笼", comment: ""))
                                        .foregroundColor(hasAttemptedSave ? .red : .secondary)
                                }
                                TextField("", text: $title)
                            }
                        }
                        .id(FormField.title)  // P0 改进：添加 ID 用于滚动定位
                    }
                
                Section(NSLocalizedString("提醒时间", comment: "")) {
                    DatePicker(L10n.reminderTime, selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    NavigationLink {
                        RepeatDaysPickerView(repeatDays: $repeatDays)
                    } label: {
                        HStack {
                            Text(L10n.reminderRepeat)
                            Spacer()
                            Text(repeatDays.displayText)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                // P0 改进：监听 scrollTarget 变化，自动滚动到未填写的表单项
                .onChange(of: scrollTarget) { _, target in
                    if let target = target {
                        withAnimation {
                            scrollProxy.scrollTo(target, anchor: .center)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollTarget = nil
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }  // Form 结束
            }  // ScrollViewReader 结束
        }
        .themedBackground()
        .themedNavigationBar(title: editingReminder == nil ? L10n.addReminder : NSLocalizedString("编辑提醒", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // P0 改进：保存按钮始终可点击，验证在点击时进行
                Button(L10n.save) {
                    hasAttemptedSave = true
                    
                    // 验证必填项
                    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        scrollTarget = .title
                        return
                    }
                    
                    // 检查离线状态
                    guard offlineService.isOnline else {
                        showOfflineAlert = true
                        return
                    }
                    
                    onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                           reminderTime,
                           repeatDays)
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(primaryColor)
            }
        }
        .alert(NSLocalizedString("无法保存", comment: ""), isPresented: $showOfflineAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("当前处于离线状态，请连网后再试", comment: ""))
        }
    }
    
    // 从 timeDescription 解析时间
    private static func parseTime(from description: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let components = description.components(separatedBy: " ")
        if let timeString = components.last, let date = formatter.date(from: timeString) {
            return date
        }
        return nil
    }
    
    // 从 timeDescription 解析重复日期
    private static func parseRepeatDays(from description: String) -> RepeatDays {
        var days = RepeatDays()
        if description.contains(L10n.daily) {
            days.sunday = true
            days.monday = true
            days.tuesday = true
            days.wednesday = true
            days.thursday = true
            days.friday = true
            days.saturday = true
        } else {
            if description.contains(NSLocalizedString("周日", comment: "")) { days.sunday = true }
            if description.contains(NSLocalizedString("周一", comment: "")) { days.monday = true }
            if description.contains(NSLocalizedString("周二", comment: "")) { days.tuesday = true }
            if description.contains(NSLocalizedString("周三", comment: "")) { days.wednesday = true }
            if description.contains(NSLocalizedString("周四", comment: "")) { days.thursday = true }
            if description.contains(NSLocalizedString("周五", comment: "")) { days.friday = true }
            if description.contains(NSLocalizedString("周六", comment: "")) { days.saturday = true }
        }
        return days
    }
}

// 重复日期选择页面（类似苹果闹钟）
struct RepeatDaysPickerView: View {
    @Binding var repeatDays: RepeatDays
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        List {
            DayToggleRow(title: NSLocalizedString("每周日", comment: ""), isOn: $repeatDays.sunday)
            DayToggleRow(title: NSLocalizedString("每周一", comment: ""), isOn: $repeatDays.monday)
            DayToggleRow(title: NSLocalizedString("每周二", comment: ""), isOn: $repeatDays.tuesday)
            DayToggleRow(title: NSLocalizedString("每周三", comment: ""), isOn: $repeatDays.wednesday)
            DayToggleRow(title: NSLocalizedString("每周四", comment: ""), isOn: $repeatDays.thursday)
            DayToggleRow(title: NSLocalizedString("每周五", comment: ""), isOn: $repeatDays.friday)
            DayToggleRow(title: NSLocalizedString("每周六", comment: ""), isOn: $repeatDays.saturday)
        }
        .themedBackground()
        .navigationTitle(L10n.reminderRepeat)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(themeManager.primaryColor.opacity(0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(themeManager.primaryColor)
    }
}

// 单个日期选择行（点击切换勾选状态）
struct DayToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ReminderFormView { title, time, repeatDays in
        print("保存: \(title), \(time), \(repeatDays.displayText)")
    }
}
