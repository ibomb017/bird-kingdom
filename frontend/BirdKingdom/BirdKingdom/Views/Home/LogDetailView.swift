import SwiftUI

/// 日志详情页面 - 查看日志内容，可点击图片放大
struct LogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    let log: BirdLog
    let onEdit: ((BirdLog) -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var showFullScreenImages = false
    @State private var selectedImageIndex = 0
    @State private var showDeleteAlert = false
    @State private var showEditView = false
    @State private var currentLog: BirdLog
    
    init(log: BirdLog, onEdit: ((BirdLog) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.log = log
        self.onEdit = onEdit
        self.onDelete = onDelete
        _currentLog = State(initialValue: log)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 头部信息
                headerSection
                
                // 图片区域
                if let imageUrls = currentLog.imageUrls, !imageUrls.isEmpty {
                    imageSection(imageUrls: imageUrls)
                }
                
                // 文字内容
                if let notes = currentLog.notes, !notes.isEmpty {
                    contentSection(notes: notes)
                }
                
                // 其他信息
                metaInfoSection
                
                Spacer(minLength: 50)
            }
            .padding(20)
        }
        .themedBackground()
        .navigationTitle(NSLocalizedString("日志详情", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEditView = true
                    } label: {
                        Label(L10n.edit, systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.primaryColor)
                }
            }
        }
        .navigationDestination(isPresented: $showFullScreenImages) {
            if let imageUrls = currentLog.imageUrls {
                FullScreenImageViewer_URLs(
                    imageURLs: imageUrls,
                    initialIndex: selectedImageIndex,
                    isPresented: $showFullScreenImages
                )
                .hidesTabBar()
            }
        }
        .navigationDestination(isPresented: $showEditView) {
            EditLogView(log: currentLog) { updatedLog in
                currentLog = updatedLog
                onEdit?(updatedLog)
            }
            .hidesTabBar()
        }
        .alert(L10n.deleteLog, isPresented: $showDeleteAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text(L10n.deleteLogConfirm)
        }
        .hidesTabBar()
    }
    
    // MARK: - 头部信息
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // 鸟名标签
            Text(currentLog.birdName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeManager.primaryColor)
                )
            
            Spacer()
            
            // 日期时间
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDate(currentLog.logDate))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(formatTime(currentLog.logDate))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 图片区域（朋友圈风格布局）
    
    private func imageSection(imageUrls: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("照片", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            // 根据图片数量选择不同布局
            imageGrid(imageUrls: imageUrls)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
        )
    }
    
    @ViewBuilder
    private func imageGrid(imageUrls: [String]) -> some View {
        let count = imageUrls.count
        
        if count == 1 {
            // 单张图片：全宽显示，保持比例
            singleImageView(urlString: imageUrls[0], index: 0)
        } else if count == 2 {
            // 2张图片：并排显示
            HStack(spacing: 8) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlString in
                    gridImageView(urlString: urlString, index: index, size: .medium)
                }
            }
        } else if count == 3 {
            // 3张图片：左边一张大的，右边两张小的
            HStack(spacing: 8) {
                gridImageView(urlString: imageUrls[0], index: 0, size: .large)
                
                VStack(spacing: 8) {
                    gridImageView(urlString: imageUrls[1], index: 1, size: .small)
                    gridImageView(urlString: imageUrls[2], index: 2, size: .small)
                }
            }
        } else if count == 4 {
            // 4张图片：2x2 网格
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    gridImageView(urlString: imageUrls[0], index: 0, size: .medium)
                    gridImageView(urlString: imageUrls[1], index: 1, size: .medium)
                }
                HStack(spacing: 8) {
                    gridImageView(urlString: imageUrls[2], index: 2, size: .medium)
                    gridImageView(urlString: imageUrls[3], index: 3, size: .medium)
                }
            }
        } else {
            // 5张及以上：3列网格
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlString in
                    gridImageView(urlString: urlString, index: index, size: .grid)
                }
            }
        }
    }
    
    // 单张图片视图（全宽，保持原始比例）
    private func singleImageView(urlString: String, index: Int) -> some View {
        Group {
            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()  // 保持比例，不裁剪
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    case .failure:
                        imagePlaceholder(height: 200)
                    default:
                        imageLoading(height: 200)
                    }
                }
                .onTapGesture {
                    selectedImageIndex = index
                    showFullScreenImages = true
                }
            }
        }
    }
    
    private enum ImageSize {
        case small, medium, large, grid
        
        var height: CGFloat {
            switch self {
            case .small: return 80
            case .medium: return 150
            case .large: return 168
            case .grid: return 100
            }
        }
    }
    
    // 网格图片视图
    private func gridImageView(urlString: String, index: Int, size: ImageSize) -> some View {
        Group {
            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: size.height)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(10)
                    case .failure:
                        imagePlaceholder(height: size.height)
                    default:
                        imageLoading(height: size.height)
                    }
                }
                .frame(height: size.height)
                .onTapGesture {
                    selectedImageIndex = index
                    showFullScreenImages = true
                }
            }
        }
    }
    
    private func imagePlaceholder(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.2))
            .frame(height: height)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
    
    private func imageLoading(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.1))
            .frame(height: height)
            .overlay(ProgressView())
    }
    
    // MARK: - 文字内容
    
    private func contentSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.healthRecords)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(notes)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
        )
    }
    
    // MARK: - 其他信息
    
    private var metaInfoSection: some View {
        VStack(spacing: 12) {
            // 体重
            if let weight = currentLog.weight {
                infoRow(icon: "scalemass.fill", title: NSLocalizedString("体重", comment: ""), value: "\(String(format: "%.1f", weight))g")
            }
            
            // 心情
            if let mood = currentLog.mood, !mood.isEmpty {
                infoRow(icon: "face.smiling", title: NSLocalizedString("心情", comment: ""), value: currentLog.moodText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
        )
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - 日期格式化
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        LogDetailView(
            log: BirdLog(
                id: 1,
                birdId: 1,
                birdName: NSLocalizedString("小绿", comment: ""),
                logDate: Date(),
                weight: 35.5,
                feedAmount: nil,
                waterAmount: nil,
                mood: "HAPPY",
                behavior: nil,
                isMolting: nil,
                isBreeding: nil,
                temperature: nil,
                humidity: nil,
                isCleaned: nil,
                healthScore: nil,
                notes: NSLocalizedString("今天小绿特别活泼，一直在笼子里蹦来蹦去，吃了很多小米。", comment: ""),
                createdAt: Date(),
                imageUrls: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
            )
        )
    }
}
