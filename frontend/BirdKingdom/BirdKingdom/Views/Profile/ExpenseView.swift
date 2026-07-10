import SwiftUI

// MARK: - 支出详情页面
struct ExpenseListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var expenseService = ExpenseService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var showAddExpense = false
    @State private var editingExpense: Expense? = nil
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var birds: [Bird] = []  // 用于根据birdId查找当前鸟名
    @State private var expenseToDelete: Expense? = nil  // 待删除确认
    
    private var filteredExpenses: [Expense] {
        if let category = selectedCategory {
            return expenseService.expenses.filter { $0.categoryEnum == category }
        }
        return expenseService.expenses
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // P2-03: 缓存过期提示（苹果原生风格）
            if expenseService.statsCacheExpired {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("统计数据可能已过期，联网后刷新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
            }
            
            // 统计卡片
            statsCard
                .padding(16)
            
            // 分类筛选
            categoryFilter
            
            // 支出列表
            if filteredExpenses.isEmpty {
                emptyState
            } else {
                expenseList
            }
        }
        .background(Color.adaptiveCard)
        .navigationTitle("支出明细")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddExpense = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(themeManager.primaryColor)
                }
            }
        }
        .navigationDestination(isPresented: $showAddExpense) {
            AddExpenseView()
                .hidesTabBar()
        }
        .navigationDestination(item: $editingExpense) { expense in
            AddExpenseView(expense: expense)
                .hidesTabBar()
        }
        .hidesTabBar()  // 进入详情页时隐藏底部导航栏
        // 每次页面出现时刷新数据（含从编辑页返回）
        .onAppear {
            Task {
                await expenseService.refresh()
                // 加载鸟列表，用于根据birdId显示当前鸟名（改名后仍能正确显示）
                if let fetchedBirds = try? await ApiService.shared.getBirds() {
                    birds = fetchedBirds
                }
            }
        }
        // 删除确认弹窗
        .alert("确认删除", isPresented: Binding(
            get: { expenseToDelete != nil },
            set: { if !$0 { expenseToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { expenseToDelete = nil }
            Button("删除", role: .destructive) {
                if let expense = expenseToDelete {
                    Task { await expenseService.deleteExpense(id: expense.id) }
                }
                expenseToDelete = nil
            }
        } message: {
            if let expense = expenseToDelete {
                let formatStr = NSLocalizedString("确定要删除「%1$@」(¥%2$@)吗？此操作不可恢复。", comment: "")
                let amountStr = String(format: "%.2f", expense.amount)
                Text(String(format: formatStr, expense.title, amountStr))
            }
        }
    }
    
    // MARK: - 统计卡片
    private var statsCard: some View {
        VStack(spacing: 16) {
            // 总支出
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(ExpenseService.formatAmount(expenseService.totalExpense))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("本月支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(ExpenseService.formatAmount(expenseService.monthlyExpense))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // 历史月份统计（如果有）
            if let monthlyStats = expenseService.stats?.monthlyStats, monthlyStats.count > 1 {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("历史支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(monthlyStats.prefix(6), id: \.month) { stat in
                                VStack(spacing: 4) {
                                    Text("¥\(Int(stat.amount))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(themeManager.primaryColor)
                                    Text(formatMonthLabel(stat.month))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 60)
                                .padding(.vertical, 8)
                                .background(themeManager.primaryColor.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // 分类统计
            HStack(spacing: 8) {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    let amount = expenseService.expensesByCategory[category] ?? 0
                    VStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.caption)
                            .foregroundColor(themeManager.primaryColor)
                        Text("¥\(Int(amount))")
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text(category.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // 格式化月份标签
    private func formatMonthLabel(_ month: String) -> String {
        // 输入格式: "2024-12"，输出: "12月"
        if let lastDash = month.lastIndex(of: "-") {
            let monthPart = month[month.index(after: lastDash)...]
            if let monthNum = Int(monthPart) {
                return "\(monthNum)月"
            }
        }
        return month
    }
    
    // MARK: - 分类筛选
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                Button {
                    selectedCategory = nil
                } label: {
                    Text("全部")
                        .font(.caption)
                        .fontWeight(selectedCategory == nil ? .semibold : .regular)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedCategory == nil ? themeManager.primaryColor : Color(uiColor: .systemGray6))
                        .foregroundColor(selectedCategory == nil ? .white : .primary)
                        .cornerRadius(16)
                }
                
                // 各分类
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.caption2)
                            Text(category.displayName)
                                .font(.caption)
                                .fontWeight(selectedCategory == category ? .semibold : .regular)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? themeManager.primaryColor : Color(uiColor: .systemGray6))
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "yensign.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("暂无支出记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击右上角 + 添加第一笔支出")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 支出列表
    private var expenseList: some View {
        List {
            ForEach(filteredExpenses) { expense in
                ExpenseRowView(expense: expense, birds: birds)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        editingExpense = expense
                    }
            }
            .onDelete { indexSet in
                // 只取第一个待删除项弹出确认
                if let first = indexSet.first {
                    expenseToDelete = filteredExpenses[first]
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 支出行视图
struct ExpenseRowView: View {
    let expense: Expense
    let birds: [Bird]  // 用于根据birdId查找当前鸟名
    @ObservedObject var themeManager = ThemeManager.shared
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()
    
    /// 根据birdId获取当前鸟名（支持改名后正确显示）
    private var currentBirdName: String? {
        // 优先使用birdId查找当前鸟名
        if let birdId = expense.birdId,
           let bird = birds.first(where: { $0.id == birdId }) {
            return bird.nickname
        }
        // 兼容旧数据：如果没有birdId，使用存储的birdName
        return expense.birdName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: expense.categoryEnum.icon)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.primaryColor)
            }
            
            // 标题和信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(expense.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 显示情侣伴侣创建的支出标签
                    if !expense.isCreatedByCurrentUser, let creatorName = expense.creatorName {
                        Text(creatorName)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(expense.categoryEnum.displayName)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.primaryColor.opacity(0.8))
                        .cornerRadius(4)
                    
                    if let birdName = currentBirdName {
                        Text(birdName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(dateFormatter.string(from: expense.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 金额
            Text("¥\(expense.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", expense.amount) : String(format: "%.2f", expense.amount))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryColor)
        }
        .padding(12)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: themeManager.primaryColor.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 添加/编辑支出视图
struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var expenseService = ExpenseService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    var expense: Expense?
    
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .food
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var selectedBirdIds: Set<Int64> = []  // 改为多选
    
    @State private var birds: [Bird] = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasAttemptedSave = false  // P0 改进：记录是否尝试过保存
    @State private var scrollTarget: FormField? = nil  // P0 改进：用于滚动到未填写的表单项
    
    // 表单字段 ID
    private enum FormField: Hashable {
        case amount
        case title
    }
    
    private var isEditing: Bool { expense != nil }
    
    // 生成关联鸟儿的名称字符串
    private var selectedBirdNames: String? {
        let names = birds.filter { selectedBirdIds.contains($0.id) }.map { $0.nickname }
        return names.isEmpty ? nil : names.joined(separator: "、")
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
                // 金额
                Section {
                    HStack {
                        Text("¥")
                            .font(.title)
                            .foregroundColor(.primary)
                        ZStack(alignment: .leading) {
                            // P0 改进：自定义 placeholder
                            if amountText.isEmpty {
                                Text("* 请输入金额")
                                    .font(.title)
                                    .foregroundColor(hasAttemptedSave ? .red : .secondary)
                            }
                            TextField("", text: $amountText)
                                .font(.title)
                                .keyboardType(.decimalPad)
                                // 过滤非法字符，只允许数字和一个小数点
                                .onChange(of: amountText) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    // 只保留第一个小数点
                                    var result = ""
                                    var hasDecimal = false
                                    for char in filtered {
                                        if char == "." {
                                            if hasDecimal { continue }
                                            hasDecimal = true
                                        }
                                        result.append(char)
                                    }
                                    // 限制小数点后最多2位
                                    if let dotIndex = result.firstIndex(of: ".") {
                                        let decimals = result[result.index(after: dotIndex)...]
                                        if decimals.count > 2 {
                                            result = String(result.prefix(result.distance(from: result.startIndex, to: dotIndex) + 3))
                                        }
                                    }
                                    if result != newValue {
                                        amountText = result
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                    .id(FormField.amount)  // P0 改进：添加 ID 用于滚动定位
                }
                
                // 基本信息
                Section {
                    // 支出名称：标签 + 自定义 placeholder
                    HStack {
                        Text("名称")
                            .foregroundColor(.primary)
                        ZStack(alignment: .leading) {
                            if title.isEmpty {
                                Text("* 请输入支出名称")
                                    .foregroundColor(hasAttemptedSave ? .red : .secondary)
                            }
                            TextField("", text: $title)
                        }
                    }
                    .id(FormField.title)  // P0 改进：添加 ID 用于滚动定位
                
                Picker("分类", selection: $category) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundColor(themeManager.primaryColor)
                            Text(cat.displayName)
                        }
                        .tag(cat)
                    }
                }
                
                DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
            }
                
                // 关联鸟儿（可选，多选）
                Section("关联鸟儿（可选，可多选）") {
                    if birds.isEmpty {
                        Text("暂无鸟儿")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(birds, id: \.id) { bird in
                            Button {
                                if selectedBirdIds.contains(bird.id) {
                                    selectedBirdIds.remove(bird.id)
                                } else {
                                    selectedBirdIds.insert(bird.id)
                                }
                            } label: {
                                HStack {
                                    Text(bird.nickname)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedBirdIds.contains(bird.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.primaryColor)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 备注
                Section("备注（可选）") {
                    TextField("添加备注...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
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
        }  // ScrollViewReader 结束
        .navigationTitle(isEditing ? "编辑支出" : "添加支出")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .foregroundColor(.secondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                // P0 改进：保存按钮始终可点击
                Button("保存") { saveExpense() }
                    .disabled(isSaving)
                    .foregroundColor(isSaving ? .gray : themeManager.primaryColor)
            }
        }
        .scrollContentBackground(.hidden)
        .alert("保存失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadBirds()
            if let expense = expense {
                title = expense.title
                amountText = expense.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", expense.amount) : String(format: "%.2f", expense.amount)
                category = expense.categoryEnum
                date = expense.date
                note = expense.note ?? ""
                // 去掉自动追加的平分备注后缀，避免编辑后叠加
                if let range = note.range(of: #" \(共\d+只鸟平分\)"#, options: .regularExpression) {
                    note = String(note[..<range.lowerBound])
                }
                // 鸟匹配延迟到 loadBirds 回调中处理，避免 birds 未加载时匹配失败
            }
        }
    }
    
    /// P0 修复：是否可以保存
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !amountText.isEmpty && 
        !isSaving
    }
    
    private func loadBirds() {
        Task {
            if let fetchedBirds = try? await ApiService.shared.getBirds() {
                await MainActor.run {
                    birds = fetchedBirds
                    // 编辑时重新解析已关联的鸟儿
                    // 优先使用 birdId 匹配，这样鸟改名后仍能正确关联
                    if let expense = expense {
                        if let birdId = expense.birdId {
                            selectedBirdIds = Set([birdId])
                        } else if let birdName = expense.birdName {
                            // 兼容旧数据：用 birdName 匹配
                            let names = birdName.components(separatedBy: "、")
                            selectedBirdIds = Set(birds.filter { names.contains($0.nickname) }.map { $0.id })
                        }
                    }
                }
            }
        }
    }
    
    private func saveExpense() {
        // P0 改进：标记已尝试保存
        hasAttemptedSave = true
        
        // 检查登录状态
        guard AuthService.shared.isLoggedIn else {
            errorMessage = "请先登录后再添加支出"
            showError = true
            return
        }
        
        // P0 改进：验证必填项并自动滚动
        if amountText.isEmpty {
            scrollTarget = .amount
            return
        }
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scrollTarget = .title
            return
        }
        
        // P1-04: 金额校验，最小0.01元
        guard let amount = Double(amountText), amount >= 0.01 else {
            errorMessage = "金额需大于等于0.01元"
            showError = true
            return
        }
        
        // 金额上限校验（防止超大金额导致数据异常）
        guard amount <= 999_999 else {
            errorMessage = "金额不能超过999,999元"
            showError = true
            return
        }
        
        isSaving = true
        
        Task {
            if isEditing, let expenseId = expense?.id {
                // 编辑模式：只更新一条记录
                let birdNames = selectedBirdNames
                let success = await expenseService.updateExpense(
                    id: expenseId,
                    title: title,
                    amount: amount,
                    category: category,
                    date: date,
                    birdId: selectedBirdIds.first,
                    birdName: birdNames,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)  // 空字符串也发送，允许清空
                )
                await MainActor.run {
                    isSaving = false
                    if success {
                        dismiss()
                    } else {
                        errorMessage = "保存失败，请检查网络连接"
                        showError = true
                    }
                }
            } else {
                // 新增模式：只有选择了多只鸟时才平分金额
                // 使用 selectedBirdIds.count 判断（Set 保证唯一，避免重复鸟导致的错误平分）
                let birdCount = selectedBirdIds.count
                
                if birdCount > 1 {
                    // 多只鸟情况：为每只鸟创建一条记录，金额平分
                    let splitAmount = amount / Double(birdCount)
                    // 金额保留两位小数
                    let formattedSplitAmount = (splitAmount * 100).rounded() / 100
                    
                    var allSuccess = true
                    // 遍历 selectedBirdIds 而非 selectedBirds，确保每个 ID 只处理一次
                    for birdId in selectedBirdIds {
                        guard let bird = birds.first(where: { $0.id == birdId }) else { continue }
                        let success = await expenseService.addExpense(
                            title: title,
                            amount: formattedSplitAmount,
                            category: category,
                            date: date,
                            birdId: bird.id,
                            birdName: bird.nickname,
                            note: note.isEmpty ? nil : (note + " (共\(birdCount)只鸟平分)")
                        )
                        if !success {
                            allSuccess = false
                        }
                    }
                    
                    await MainActor.run {
                        isSaving = false
                        if allSuccess {
                            dismiss()
                        } else {
                            errorMessage = "部分记录保存失败，请检查网络连接"
                            showError = true
                        }
                    }
                } else {
                    // 单只鸟或无鸟情况：正常创建一条记录（不平分）
                    let birdId = selectedBirdIds.first
                    let birdName = birdId.flatMap { id in birds.first(where: { $0.id == id })?.nickname }
                    
                    let success = await expenseService.addExpense(
                        title: title,
                        amount: amount,  // 原始金额，不平分
                        category: category,
                        date: date,
                        birdId: birdId,
                        birdName: birdName,
                        note: note.isEmpty ? nil : note
                    )
                    await MainActor.run {
                        isSaving = false
                        if success {
                            dismiss()
                        } else {
                            errorMessage = "保存失败，请检查网络连接"
                            showError = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ExpenseListView()
}
