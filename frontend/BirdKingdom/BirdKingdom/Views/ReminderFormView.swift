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
            return "永不"
        }
        if isEveryday {
            return "每天"
        }
        
        var days: [String] = []
        if sunday { days.append("周日") }
        if monday { days.append("周一") }
        if tuesday { days.append("周二") }
        if wednesday { days.append("周三") }
        if thursday { days.append("周四") }
        if friday { days.append("周五") }
        if saturday { days.append("周六") }
        
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
    
    let editingReminder: Reminder?  // nil 表示新建
    let onSave: (String, Date, RepeatDays) -> Void
    
    @State private var title: String = ""
    @State private var reminderTime: Date = Date()
    @State private var repeatDays: RepeatDays = RepeatDays()
    
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("提醒内容") {
                    TextField("例如：喂食、小鸟体检、清洁鸟笼", text: $title)
                }
                
                Section("提醒时间") {
                    DatePicker("时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    NavigationLink {
                        RepeatDaysPickerView(repeatDays: $repeatDays)
                    } label: {
                        HStack {
                            Text("重复")
                            Spacer()
                            Text(repeatDays.displayText)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(editingReminder == nil ? "添加提醒" : "编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                               reminderTime,
                               repeatDays)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // 从 timeDescription 解析时间
    private static func parseTime(from description: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let components = description.components(separatedBy: " ")
        if let timeString = components.last, let date = formatter.date(from: timeString) {
            return date
        }
        return nil
    }
    
    // 从 timeDescription 解析重复日期
    private static func parseRepeatDays(from description: String) -> RepeatDays {
        var days = RepeatDays()
        if description.contains("每天") {
            days.sunday = true
            days.monday = true
            days.tuesday = true
            days.wednesday = true
            days.thursday = true
            days.friday = true
            days.saturday = true
        } else {
            if description.contains("周日") { days.sunday = true }
            if description.contains("周一") { days.monday = true }
            if description.contains("周二") { days.tuesday = true }
            if description.contains("周三") { days.wednesday = true }
            if description.contains("周四") { days.thursday = true }
            if description.contains("周五") { days.friday = true }
            if description.contains("周六") { days.saturday = true }
        }
        return days
    }
}

// 重复日期选择页面（类似苹果闹钟）
struct RepeatDaysPickerView: View {
    @Binding var repeatDays: RepeatDays
    
    var body: some View {
        List {
            DayToggleRow(title: "每周日", isOn: $repeatDays.sunday)
            DayToggleRow(title: "每周一", isOn: $repeatDays.monday)
            DayToggleRow(title: "每周二", isOn: $repeatDays.tuesday)
            DayToggleRow(title: "每周三", isOn: $repeatDays.wednesday)
            DayToggleRow(title: "每周四", isOn: $repeatDays.thursday)
            DayToggleRow(title: "每周五", isOn: $repeatDays.friday)
            DayToggleRow(title: "每周六", isOn: $repeatDays.saturday)
        }
        .navigationTitle("重复")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 单个日期选择行（点击切换勾选状态）
struct DayToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
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
                        .foregroundColor(.orange)
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
