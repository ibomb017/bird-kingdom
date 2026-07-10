import Vapor

/// 用户 DTO
struct UserDTO: Content {
    let id: Int64  // 改为非可选，匹配前端期望
    let phone: String?
    let nickname: String?
    let avatarUrl: String?
    let bio: String?
    let isVip: Bool?
    let vipType: String?
    let vipExpireDate: Date?
    let isCoupleVip: Bool?
    let couplePartnerId: Int64?
    let pendingCouplePhone: String?
    let pendingCoupleInvitationFrom: Int64?
    let role: String?
    let createdAt: Date?
    
    // 统计数据（可选）
    var birdCount: Int?
    var postCount: Int?
    var followerCount: Int?
    var followingCount: Int?
    
    // 🔧 FIX: 添加前端需要的额外字段
    let hasPassword: Bool?           // 是否已设置密码
    let logCount: Int?               // 日志数量
    let activeDays: Int?             // 活跃天数
    let couplePartnerName: String?   // 情侣伴侣名称
    let couplePartnerAvatar: String? // 情侣伴侣头像
    let pendingCouplePartnerName: String? // 待确认伴侣名称
    let isPendingConfirmation: Bool? // 是否等待对方确认
    
    static func from(_ user: User) -> UserDTO {
        UserDTO(
            id: user.id ?? 0,  // 使用默认值0
            phone: user.phone,
            nickname: user.nickname,
            avatarUrl: user.avatarUrl,
            bio: user.bio,
            isVip: user.isVip,
            vipType: user.vipType,
            vipExpireDate: user.vipExpireDate,
            isCoupleVip: user.isCoupleVip,
            couplePartnerId: user.couplePartnerId,
            pendingCouplePhone: user.pendingCouplePhone,
            pendingCoupleInvitationFrom: user.pendingCoupleInvitationFrom,
            role: user.role,
            createdAt: user.createdAt,
            // 🔧 FIX: 填充新字段
            hasPassword: user.password != nil,
            logCount: nil, // 需要在Controller中计算
            activeDays: nil, // 需要在Controller中计算
            couplePartnerName: nil, // 需要在Controller中查询
            couplePartnerAvatar: nil, // 需要在Controller中查询
            pendingCouplePartnerName: nil, // 需要在Controller中查询
            isPendingConfirmation: user.pendingCoupleInvitationFrom != nil
        )
    }
}

/// 帖子 DTO
struct ForumPostDTO: Content {
    let id: Int64
    let authorId: Int64
    let authorName: String?
    let authorAvatar: String?
    let content: String
    let postType: String?
    let mediaType: String?
    let videoUrl: String?
    let videoCover: String?
    let videoDuration: Int?
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let distance: Double?  // 附近流：与用户的距离（km）
    let birdId: Int64?
    let birdIds: String?
    let birdsInfo: String?
    let birdName: String?
    let birdSpecies: String?
    let birdAvatar: String?
    let lostLocation: String?
    let contactPhone: String?
    let reward: String?
    let isFound: Bool?
    let images: [String]
    let isLiked: Bool?
    let isFavorited: Bool?
    let createdAt: Date?
    
    // 🔧 FIX: 添加前端需要的额外字段
    let favoriteCount: Int?      // 收藏数
    let isFollowing: Bool?        // 是否关注作者
    let timeAgo: String?          // 相对时间（如"3小时前"）
    
    static func from(
        _ post: ForumPost,
        author: User?,
        images: [PostImage],
        isLiked: Bool = false,
        isFavorited: Bool = false,
        distance: Double? = nil,
        // 🔧 FIX: 新参数
        favoriteCount: Int? = nil,
        isFollowing: Bool? = nil
    ) -> ForumPostDTO {
        ForumPostDTO(
            id: post.id ?? 0,
            authorId: post.authorId,
            authorName: author?.nickname,
            authorAvatar: author?.avatarUrl,
            content: post.content,
            postType: post.postType,
            mediaType: post.mediaType,
            videoUrl: post.videoUrl,
            videoCover: post.videoCover,
            videoDuration: post.videoDuration,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            viewCount: post.viewCount,
            latitude: post.latitude,
            longitude: post.longitude,
            locationName: post.locationName,
            distance: distance,
            birdId: post.birdId,
            birdIds: post.birdIds,
            birdsInfo: post.birdsInfo,
            birdName: post.birdName,
            birdSpecies: post.birdSpecies,
            birdAvatar: post.birdAvatar,
            lostLocation: post.lostLocation,
            contactPhone: post.contactPhone,
            reward: post.reward,
            isFound: post.isFound,
            images: images.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }.map { $0.imageUrl },
            isLiked: isLiked,
            isFavorited: isFavorited,
            createdAt: post.createdAt,
            // 🔧 FIX: 填充新字段
            favoriteCount: favoriteCount,  // 直接使用参数，不从post获取
            isFollowing: isFollowing,
            timeAgo: post.createdAt?.timeAgoString()
        )
    }
}

// 🔧 FIX: 添加Date扩展用于计算相对时间
extension Date {
    func timeAgoString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)年前"
        } else if let months = components.month, months > 0 {
            return "\(months)个月前"
        } else if let days = components.day, days > 0 {
            return "\(days)天前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)小时前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
}

/// 评论 DTO
struct CommentDTO: Content {
    let id: Int64
    let postId: Int64
    let authorId: Int64
    let authorName: String?
    let authorAvatar: String?
    let content: String
    let parentId: Int64?
    let likeCount: Int?
    let isLiked: Bool?
    let replies: [CommentDTO]?
    let createdAt: Date?
    
    // 🔧 FIX: 添加前端需要的额外字段
    let parentAuthorName: String?  // 父评论作者名（用于@显示）
    let timeAgo: String?            // 相对时间
    
    // 👑 VIP 相关字段
    let authorIsVip: Bool?
    let authorVipType: String?
    let authorIsCoupleVip: Bool?
    let authorCouplePartnerId: Int64?
    
    static func from(
        _ comment: PostComment,
        author: User?,
        isLiked: Bool = false,
        replies: [CommentDTO]? = nil,
        // 🔧 FIX: 新参数
        parentAuthorName: String? = nil
    ) -> CommentDTO {
        CommentDTO(
            id: comment.id ?? 0,
            postId: comment.postId,
            authorId: comment.authorId,
            authorName: author?.nickname,
            authorAvatar: author?.avatarUrl,
            content: comment.content,
            parentId: comment.parentId,
            likeCount: comment.likeCount ?? 0,
            isLiked: isLiked,
            replies: replies,
            createdAt: comment.createdAt,
            // 🔧 FIX: 填充新字段
            parentAuthorName: parentAuthorName,
            timeAgo: comment.createdAt?.timeAgoString(),
            authorIsVip: author?.isVip,
            authorVipType: author?.vipType,
            authorIsCoupleVip: author?.isCoupleVip,
            authorCouplePartnerId: author?.couplePartnerId
        )
    }
}

/// 鸟儿 DTO
struct BirdDTO: Content {
    let id: Int64
    let nickname: String
    let species: String
    let gender: String?
    let hatchDate: Date?
    let adoptionDate: Date?
    let birthdayType: String?
    let featherColor: String?
    let source: String?
    let fatherInfo: String?
    let motherInfo: String?
    let legRingId: String?
    let avatarUrl: String?
    let notes: String?
    let medicalHistory: String?
    let deathDate: Date?
    let isDeleted: Bool
    let isLost: Bool
    let lostDate: Date?
    let lostLocation: String?
    let lostPostId: Int64?
    let userId: Int64?
    let createdAt: Date?
    let updatedAt: Date?
    
    // 🔧 FIX: 添加前端需要的额外字段
    let ageMonths: Int?          // 年龄月数
    let deletedAt: Date?          // 删除时间
    let ownerId: Int64?           // 主人ID（userId别名）
    let ownerName: String?        // 主人名称
    let isShared: Bool?           // 是否被共享
    let sharedWith: [BirdCoOwnerDTO]?  // 共享给的用户列表
    let shareRole: String?        // 当前用户对此鸟的角色
    let isOwner: Bool?            // 是否是原始主人
    let isCoupleShared: Bool?     // 是否是情侣共享
    
    static func from(
        _ bird: Bird,
        ageMonths: Int? = nil,
        ownerName: String? = nil,
        isShared: Bool? = nil,
        sharedWith: [BirdCoOwnerDTO]? = nil,
        shareRole: String? = nil,
        isOwner: Bool? = nil,
        isCoupleShared: Bool? = nil
    ) -> BirdDTO {
        BirdDTO(
            id: bird.id ?? 0,
            nickname: bird.nickname,
            species: bird.species,
            gender: bird.gender,
            hatchDate: bird.hatchDate,
            adoptionDate: bird.adoptionDate,
            birthdayType: bird.birthdayType,
            featherColor: bird.featherColor,
            source: bird.source,
            fatherInfo: bird.fatherInfo,
            motherInfo: bird.motherInfo,
            legRingId: bird.legRingId,
            avatarUrl: bird.avatarUrl,
            notes: bird.notes,
            medicalHistory: bird.medicalHistory,
            deathDate: bird.deathDate,
            isDeleted: bird.isDeleted,
            isLost: bird.isLost,
            lostDate: bird.lostDate,
            lostLocation: bird.lostLocation,
            lostPostId: bird.lostPostId,
            userId: bird.userId,
            createdAt: bird.createdAt,
            updatedAt: bird.updatedAt,
            // 🔧 FIX: 填充新字段
            ageMonths: ageMonths,
            deletedAt: bird.deletedAt,
            ownerId: bird.userId,  // ownerId = userId
            ownerName: ownerName,
            isShared: isShared,
            sharedWith: sharedWith,
            shareRole: shareRole,
            isOwner: isOwner,
            isCoupleShared: isCoupleShared
        )
    }
}

// 🔧 FIX: 添加BirdCoOwnerDTO
struct BirdCoOwnerDTO: Content {
    let id: Int64
    let userId: Int64
    let nickname: String
    let avatar: String?
    let phone: String?
    let role: String
    let sharedAt: Date?
}

/// 分页响应
struct PageResponse<T: Content>: Content {
    let content: [T]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
    
    init(content: [T], page: Int, size: Int, total: Int) {
        self.content = content
        self.totalElements = total
        self.totalPages = total > 0 ? Int(ceil(Double(total) / Double(size))) : 0
        self.number = page
        self.size = size
        self.first = page == 0
        self.last = page >= totalPages - 1 || totalPages == 0
    }
}
