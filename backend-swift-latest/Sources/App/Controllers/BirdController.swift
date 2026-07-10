import Vapor
import Fluent

/// 鸟儿控制器
struct BirdController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let birds = routes.grouped("birds")
        
        // 需要认证的路由
        let protected = birds.grouped(JWTAuthMiddleware())
        
        // 获取我的鸟儿列表
        protected.get(use: getMyBirds)
        
        // 获取单只鸟儿
        protected.get(":birdId", use: getBird)
        
        // 添加鸟儿
        protected.post(use: createBird)
        
        // 更新鸟儿
        protected.put(":birdId", use: updateBird)
        
        // 删除鸟儿（软删除）
        protected.delete(":birdId", use: deleteBird)
        
        // 恢复已删除的鸟儿
        protected.post(":birdId", "restore", use: restoreBird)
        
        // 永久删除鸟儿
        protected.delete(":birdId", "permanent", use: permanentDeleteBird)
        
        // 获取已删除的鸟儿（回收站）
        protected.get("deleted", use: getDeletedBirds)
        
        // 更新鸟儿丢失状态
        protected.put(":birdId", "lost-status", use: updateLostStatus)
        
        // 标记鸟儿丢失
        protected.post(":birdId", "lost", use: markLost)
        
        // 标记鸟儿找回
        protected.post(":birdId", "found", use: markFound)
        
        // 标记鸟儿死亡
        protected.post(":birdId", "death", use: markDeath)
        
        // 获取活跃的鸟（非回收站）
        protected.get("active", use: getActiveBirds)
        
        // 鸟分享功能
        protected.post(":birdId", "share", use: shareBird)
        protected.get(":birdId", "shared-users", use: getSharedUsers)
        protected.delete(":birdId", "shared-users", ":userId", use: removeSharedUser)
        protected.put(":birdId", "shared-users", ":userId", use: updateSharedUserRole)
        protected.patch(":birdId", "shared-users", ":userId", use: updateSharedUserRole)  // 兼容前端 PATCH 方法
        protected.post(":birdId", "leave", use: leaveBirdShare)
        
        // 嵌套日志路由 /birds/:birdId/logs（REST 风格兼容路由）
        protected.get(":birdId", "logs", use: getBirdLogs)
        protected.post(":birdId", "logs", use: createBirdLog)
        protected.put(":birdId", "logs", ":logId", use: updateBirdLog)
        protected.delete(":birdId", "logs", ":logId", use: deleteBirdLog)
        
        // 体重管理接口
        protected.get(":birdId", "weights", use: getBirdWeights)
        protected.post(":birdId", "weights", use: addBirdWeight)
        protected.delete(":birdId", "weights", ":weightId", use: deleteBirdWeight)
    }

    
    // MARK: - 获取我的鸟儿列表（包括伴侣的鸟）
    @Sendable
    func getMyBirds(req: Request) async throws -> [BirdDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        // 获取当前用户信息，检查是否有伴侣
        guard let currentUser = try await User.find(userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "用户不存在")
        }
        let partnerUserId = currentUser.couplePartnerId
        
        // FIX: 获取伴侣昵称（如果有）
        var partnerNickname: String? = nil
        if let partnerId = partnerUserId {
            if let partner = try await User.find(partnerId, on: req.db) {
                partnerNickname = partner.nickname
            }
        }
        
        // 构建用户ID列表（自己 + 伴侣）
        var userIds = [userId]
        if let partnerId = partnerUserId {
            userIds.append(partnerId)
        }
        
        // 查询自己和伴侣的所有鸟
        let birds = try await Bird.query(on: req.db)
            .filter(\.$userId ~~ userIds)
            .filter(\.$isDeleted == false)
            .sort(\.$createdAt, .descending)
            .all()
        
        // FIX: 正确填充情侣共享鸟的信息
        return birds.map { bird in
            let isCoupleShared = bird.userId != userId && bird.userId == partnerUserId
            let ownerName = isCoupleShared ? partnerNickname : nil
            let isOwner = bird.userId == userId
            
            return BirdDTO.from(
                bird,
                ownerName: ownerName,
                isOwner: isOwner,
                isCoupleShared: isCoupleShared
            )
        }
    }
    
    // MARK: - 获取单只鸟儿
    @Sendable
    func getBird(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // 检查权限：鸟主人或情侣伴侣
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权访问此鸟儿")
        }
        
        return BirdDTO.from(bird)
    }
    
    /// 检查用户是否有权访问某只鸟（包括情侣伴侣和共享用户）
    /// - Parameters:
    ///   - userId: 当前用户ID
    ///   - bird: 要检查的鸟
    ///   - db: 数据库连接
    ///   - requireEditPermission: 是否需要编辑权限（默认false，仅查看）
    /// - Returns: 是否有权限
    private func checkBirdAccess(userId: Int64, bird: Bird, on db: Database, requireEditPermission: Bool = false) async throws -> Bool {
        // 鸟主人 - 完全权限
        if bird.userId == userId {
            return true
        }
        
        // 检查是否是情侣伴侣 - 完全权限
        if let user = try await User.find(userId, on: db),
           let partnerId = user.couplePartnerId,
           bird.userId == partnerId {
            return true
        }
        
        // 检查共享权限
        guard let birdId = bird.id else { return false }
        let share = try await BirdShare.query(on: db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == userId)
            .filter(\.$status == "ACCEPTED")
            .first()
        
        if let share = share {
            // 如果需要编辑权限，检查 role
            if requireEditPermission {
                return share.role == "EDIT" || share.role == "ADMIN"
            }
            // 仅需查看权限
            return true
        }
        
        return false
    }
    
    /// 检查用户是否有编辑某只鸟的权限
    private func checkBirdEditAccess(userId: Int64, bird: Bird, on db: Database) async throws -> Bool {
        return try await checkBirdAccess(userId: userId, bird: bird, on: db, requireEditPermission: true)
    }
    
    // MARK: - 添加鸟儿
    @Sendable
    func createBird(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct CreateBirdRequest: Content {
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
        }
        
        let input = try req.content.decode(CreateBirdRequest.self)
        
        let bird = Bird(
            nickname: input.nickname,
            species: input.species,
            gender: input.gender,
            hatchDate: input.hatchDate,
            adoptionDate: input.adoptionDate,
            birthdayType: input.birthdayType,
            featherColor: input.featherColor,
            source: input.source,
            fatherInfo: input.fatherInfo,
            motherInfo: input.motherInfo,
            legRingId: input.legRingId,
            avatarUrl: input.avatarUrl,
            notes: input.notes,
            medicalHistory: input.medicalHistory,
            userId: userId
        )
        
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 更新鸟儿
    @Sendable
    func updateBird(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权修改此鸟儿")
        }
        
        struct UpdateBirdRequest: Content {
            let nickname: String?
            let species: String?
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
        }
        
        let input = try req.content.decode(UpdateBirdRequest.self)
        
        if let nickname = input.nickname { bird.nickname = nickname }
        if let species = input.species { bird.species = species }
        if let gender = input.gender { bird.gender = gender }
        if let hatchDate = input.hatchDate { bird.hatchDate = hatchDate }
        if let adoptionDate = input.adoptionDate { bird.adoptionDate = adoptionDate }
        if let birthdayType = input.birthdayType { bird.birthdayType = birthdayType }
        if let featherColor = input.featherColor { bird.featherColor = featherColor }
        if let source = input.source { bird.source = source }
        if let fatherInfo = input.fatherInfo { bird.fatherInfo = fatherInfo }
        if let motherInfo = input.motherInfo { bird.motherInfo = motherInfo }
        if let legRingId = input.legRingId { bird.legRingId = legRingId }
        if let avatarUrl = input.avatarUrl { bird.avatarUrl = avatarUrl }
        if let notes = input.notes { bird.notes = notes }
        if let medicalHistory = input.medicalHistory { bird.medicalHistory = medicalHistory }
        
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 删除鸟儿（软删除）
    @Sendable
    func deleteBird(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "无权删除此鸟儿")
        }
        
        bird.isDeleted = true
        bird.deletedAt = Date()
        try await bird.save(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 恢复已删除的鸟儿
    @Sendable
    func restoreBird(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "无权操作此鸟儿")
        }
        
        bird.isDeleted = false
        bird.deletedAt = nil
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 永久删除鸟儿
    @Sendable
    func permanentDeleteBird(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "无权删除此鸟儿")
        }
        
        // 物理删除
        try await bird.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 获取已删除的鸟儿（回收站）
    @Sendable
    func getDeletedBirds(req: Request) async throws -> [BirdDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let birds = try await Bird.query(on: req.db)
            .filter(\.$userId == userId)
            .filter(\.$isDeleted == true)
            .sort(\.$deletedAt, .descending)
            .all()
        
        return birds.map { BirdDTO.from($0) }
    }
    
    // MARK: - 更新鸟儿丢失状态
    @Sendable
    func updateLostStatus(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        struct LostStatusRequest: Content {
            let isLost: Bool
            let lostDate: String?
            let lostLocation: String?
        }
        
        let input = try req.content.decode(LostStatusRequest.self)
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作此鸟儿")
        }
        
        bird.isLost = input.isLost
        if input.isLost {
            // 解析日期
            if let dateStr = input.lostDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                bird.lostDate = formatter.date(from: dateStr)
            } else {
                bird.lostDate = Date()
            }
            bird.lostLocation = input.lostLocation
        } else {
            bird.lostDate = nil
            bird.lostLocation = nil
            bird.lostPostId = nil
        }
        
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 标记鸟儿丢失
    @Sendable
    func markLost(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作此鸟儿")
        }
        
        struct MarkLostRequest: Content {
            let lostDate: Date?
            let lostLocation: String?
            let lostPostId: Int64?
        }
        
        let input = try req.content.decode(MarkLostRequest.self)
        
        bird.isLost = true
        bird.lostDate = input.lostDate ?? Date()
        bird.lostLocation = input.lostLocation
        bird.lostPostId = input.lostPostId
        
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 标记鸟儿找回
    @Sendable
    func markFound(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作此鸟儿")
        }
        
        bird.isLost = false
        bird.lostDate = nil
        bird.lostLocation = nil
        bird.lostPostId = nil
        
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 标记鸟儿死亡
    @Sendable
    func markDeath(req: Request) async throws -> BirdDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作此鸟儿")
        }
        
        struct MarkDeathRequest: Content {
            let deathDate: Date?
        }
        
        let input = try req.content.decode(MarkDeathRequest.self)
        
        bird.deathDate = input.deathDate ?? Date()
        
        try await bird.save(on: req.db)
        
        return BirdDTO.from(bird)
    }
    
    // MARK: - 获取活跃的鸟（非回收站）
    @Sendable
    func getActiveBirds(req: Request) async throws -> [BirdDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        // 获取当前用户信息，检查是否有伴侣
        guard let currentUser = try await User.find(userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "用户不存在")
        }
        let partnerUserId = currentUser.couplePartnerId
        
        // 获取伴侣昵称（如果有）
        var partnerNickname: String? = nil
        if let partnerId = partnerUserId {
            if let partner = try await User.find(partnerId, on: req.db) {
                partnerNickname = partner.nickname
            }
        }
        
        // 构建用户ID列表（自己 + 伴侣）
        var userIds = [userId]
        if let partnerId = partnerUserId {
            userIds.append(partnerId)
        }
        
        // 查询自己和伴侣的所有活跃鸟（非回收站）
        let birds = try await Bird.query(on: req.db)
            .filter(\.$userId ~~ userIds)
            .filter(\.$isDeleted == false)
            .sort(\.$createdAt, .descending)
            .all()
        
        // 填充情侣共享鸟的信息
        return birds.map { bird in
            let isCoupleShared = bird.userId != userId && bird.userId == partnerUserId
            let ownerName = isCoupleShared ? partnerNickname : nil
            let isOwner = bird.userId == userId
            
            return BirdDTO.from(
                bird,
                ownerName: ownerName,
                isOwner: isOwner,
                isCoupleShared: isCoupleShared
            )
        }
    }
    
    // MARK: - 分享鸟给其他用户
    @Sendable
    func shareBird(req: Request) async throws -> ShareBirdResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        struct ShareRequest: Content {
            let targetUserId: Int64
            let role: String?  // "VIEW" or "EDIT"
        }
        
        let input = try req.content.decode(ShareRequest.self)
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "只有主人才能分享鸟儿")
        }
        
        // 检查目标用户是否存在
        guard try await User.find(input.targetUserId, on: req.db) != nil else {
            throw Abort(.notFound, reason: "目标用户不存在")
        }
        
        // 检查是否已分享
        let existingShare = try await BirdShare.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == input.targetUserId)
            .first()
        
        if existingShare != nil {
            throw Abort(.conflict, reason: "已分享给该用户")
        }
        
        // 创建分享记录 - 直接分享时状态为 ACCEPTED（无需对方确认）
        let share = BirdShare(
            birdId: birdId,
            ownerId: userId,
            sharedUserId: input.targetUserId,
            role: input.role ?? "VIEW",
            status: "ACCEPTED"
        )
        try await share.save(on: req.db)
        
        return ShareBirdResponse(success: true, message: "分享成功")
    }
    
    // MARK: - 获取共享用户列表
    @Sendable
    func getSharedUsers(req: Request) async throws -> [SharedUserDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // 只有主人可以查看共享列表
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "只有主人才能查看共享列表")
        }
        
        let shares = try await BirdShare.query(on: req.db)
            .filter(\.$birdId == birdId)
            .all()
        
        var results: [SharedUserDTO] = []
        for share in shares {
            if let user = try await User.find(share.sharedUserId, on: req.db) {
                results.append(SharedUserDTO(
                    userId: user.id ?? 0,
                    nickname: user.nickname,
                    avatarUrl: user.avatarUrl,
                    role: share.role ?? "VIEWER",
                    sharedAt: share.createdAt
                ))
            }
        }
        
        return results
    }
    
    // MARK: - 移除共享用户
    @Sendable
    func removeSharedUser(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr),
              let targetUserIdStr = req.parameters.get("userId"),
              let targetUserId = Int64(targetUserIdStr) else {
            throw Abort(.badRequest, reason: "无效的参数")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "只有主人才能移除共享用户")
        }
        
        // 删除分享记录
        try await BirdShare.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == targetUserId)
            .delete()
        
        return .noContent
    }
    
    // MARK: - 更新共享用户角色
    @Sendable
    func updateSharedUserRole(req: Request) async throws -> SharedUserDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr),
              let targetUserIdStr = req.parameters.get("userId"),
              let targetUserId = Int64(targetUserIdStr) else {
            throw Abort(.badRequest, reason: "无效的参数")
        }
        
        struct UpdateRoleRequest: Content {
            let role: String  // "VIEW" or "EDIT"
        }
        
        let input = try req.content.decode(UpdateRoleRequest.self)
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "只有主人才能更新共享权限")
        }
        
        guard let share = try await BirdShare.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == targetUserId)
            .first() else {
            throw Abort(.notFound, reason: "未找到共享记录")
        }
        
        share.role = input.role
        try await share.save(on: req.db)
        
        guard let user = try await User.find(targetUserId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        return SharedUserDTO(
            userId: user.id ?? 0,
            nickname: user.nickname,
            avatarUrl: user.avatarUrl,
            role: share.role ?? "VIEWER",
            sharedAt: share.createdAt
        )
    }
    
    // MARK: - 离开共享（被分享者主动退出）
    @Sendable
    func leaveBirdShare(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        // 删除自己作为共享用户的记录
        try await BirdShare.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == userId)
            .delete()
        
        return .noContent
    }
    
    // MARK: - 获取鸟的日志（嵌套路由 /birds/:birdId/logs）
    @Sendable
    func getBirdLogs(req: Request) async throws -> [BirdLogDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // 检查权限
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权访问此鸟儿")
        }
        
        let logs = try await BirdLog.query(on: req.db)
            .filter(\.$birdId == birdId)
            .sort(\.$logDate, .descending)
            .all()
        
        // 批量查询日志图片
        let logIds = logs.compactMap { $0.id }
        let allImages = try await BirdLogImage.query(on: req.db)
            .filter(\.$logId ~~ logIds)
            .sort(\.$sortOrder, .ascending)
            .all()
        
        var imageUrlsMap: [Int64: [String]] = [:]
        for image in allImages {
            if imageUrlsMap[image.logId] == nil {
                imageUrlsMap[image.logId] = []
            }
            imageUrlsMap[image.logId]?.append(image.imageUrl)
        }
        
        return logs.map { log in
            let imageUrls = log.id.flatMap { imageUrlsMap[$0] }
            return BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: imageUrls)
        }
    }
    
    // MARK: - 创建鸟的日志
    @Sendable
    func createBirdLog(req: Request) async throws -> BirdLogDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // FIX: 使用 checkBirdEditAccess 支持伴侣和共享用户
        let hasAccess = try await checkBirdEditAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作该鸟")
        }
        
        struct CreateLogRequest: Content {
            let logDate: Date?
            let weight: Double?
            let notes: String?
            let imageUrls: [String]?
        }
        
        let input = try req.content.decode(CreateLogRequest.self)
        
        let log = BirdLog(
            birdId: birdId,
            logDate: input.logDate ?? Date(),
            weight: input.weight,
            notes: input.notes ?? ""
        )
        try await log.save(on: req.db)
        
        // 保存日志图片
        if let imageUrls = input.imageUrls, !imageUrls.isEmpty {
            for (index, url) in imageUrls.enumerated() {
                let image = BirdLogImage(logId: log.id!, imageUrl: url, sortOrder: index)
                try await image.save(on: req.db)
            }
        }
        
        return BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: input.imageUrls)
    }
    
    // MARK: - 更新鸟的日志
    @Sendable
    func updateBirdLog(req: Request) async throws -> BirdLogDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr),
              let logIdStr = req.parameters.get("logId"),
              let logId = Int64(logIdStr) else {
            throw Abort(.badRequest, reason: "无效的参数")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // FIX: 使用 checkBirdEditAccess 支持伴侣和共享用户
        let hasAccess = try await checkBirdEditAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作该鸟")
        }
        
        guard let log = try await BirdLog.find(logId, on: req.db),
              log.birdId == birdId else {
            throw Abort(.notFound, reason: "日志不存在")
        }
        
        struct UpdateLogRequest: Content {
            let logDate: Date?
            let weight: Double?
            let mood: String?
            let behavior: String?
            let notes: String?
            let healthScore: Int?
            let imageUrls: [String]?
        }
        
        let input = try req.content.decode(UpdateLogRequest.self)
        
        if let logDate = input.logDate { log.logDate = logDate }
        if let weight = input.weight { log.weight = weight }
        if let mood = input.mood { log.mood = mood }
        if let behavior = input.behavior { log.behavior = behavior }
        if let notes = input.notes { log.notes = notes }
        if let healthScore = input.healthScore { log.healthScore = healthScore }
        
        try await log.save(on: req.db)
        
        // 更新图片
        var updatedImageUrls: [String]? = nil
        if let imageUrls = input.imageUrls {
            try await BirdLogImage.query(on: req.db)
                .filter(\.$logId == logId)
                .delete()
            
            for (index, url) in imageUrls.enumerated() {
                let image = BirdLogImage(logId: logId, imageUrl: url, sortOrder: index)
                try await image.save(on: req.db)
            }
            updatedImageUrls = imageUrls
        }
        
        return BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: updatedImageUrls)
    }
    
    // MARK: - 删除鸟的日志
    @Sendable
    func deleteBirdLog(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr),
              let logIdStr = req.parameters.get("logId"),
              let logId = Int64(logIdStr) else {
            throw Abort(.badRequest, reason: "无效的参数")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // FIX: 使用 checkBirdEditAccess 支持伴侣和共享用户
        let hasAccess = try await checkBirdEditAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权操作该鸟")
        }
        
        guard let log = try await BirdLog.find(logId, on: req.db),
              log.birdId == birdId else {
            throw Abort(.notFound, reason: "日志不存在")
        }
        
        // 删除关联图片
        try await BirdLogImage.query(on: req.db)
            .filter(\.$logId == logId)
            .delete()
        
        try await log.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 获取鸟的体重记录
    @Sendable
    func getBirdWeights(req: Request) async throws -> [WeightRecordDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        // 检查权限
        let hasAccess = try await checkBirdAccess(userId: userId, bird: bird, on: req.db)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权访问此鸟儿")
        }
        
        // 从日志中获取有体重记录的数据
        let logs = try await BirdLog.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$weight != nil)
            .sort(\.$logDate, .descending)
            .all()
        
        return logs.compactMap { log -> WeightRecordDTO? in
            guard let weight = log.weight else { return nil }
            return WeightRecordDTO(
                id: log.id ?? 0,
                birdId: log.birdId,
                weight: weight,
                recordDate: log.logDate,
                notes: log.notes
            )
        }
    }
    
    // MARK: - 添加体重记录
    @Sendable
    func addBirdWeight(req: Request) async throws -> WeightRecordDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟儿ID")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "无权操作该鸟")
        }
        
        struct AddWeightRequest: Content {
            let weight: Double
            let recordDate: Date?
            let notes: String?
        }
        
        let input = try req.content.decode(AddWeightRequest.self)
        
        // 创建带有体重的日志记录
        let log = BirdLog(
            birdId: birdId,
            logDate: input.recordDate ?? Date(),
            weight: input.weight,
            notes: input.notes ?? "体重记录"
        )
        try await log.save(on: req.db)
        
        return WeightRecordDTO(
            id: log.id ?? 0,
            birdId: log.birdId,
            weight: input.weight,
            recordDate: log.logDate,
            notes: log.notes
        )
    }
    
    // MARK: - 删除体重记录
    @Sendable
    func deleteBirdWeight(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr),
              let weightIdStr = req.parameters.get("weightId"),
              let weightId = Int64(weightIdStr) else {
            throw Abort(.badRequest, reason: "无效的参数")
        }
        
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        if bird.userId != userId {
            throw Abort(.forbidden, reason: "无权操作该鸟")
        }
        
        // 体重记录存储在日志表中，通过日志ID删除
        guard let log = try await BirdLog.find(weightId, on: req.db),
              log.birdId == birdId else {
            throw Abort(.notFound, reason: "体重记录不存在")
        }
        
        // 删除关联图片
        try await BirdLogImage.query(on: req.db)
            .filter(\.$logId == weightId)
            .delete()
        
        try await log.delete(on: req.db)
        
        return .noContent
    }
}

// MARK: - 体重记录 DTO
struct WeightRecordDTO: Content {
    let id: Int64
    let birdId: Int64
    let weight: Double
    let recordDate: Date
    let notes: String?
}

// 注意: BirdShare 模型定义在 Models/AdditionalModels.swift 中

// MARK: - 分享响应 DTOs
struct ShareBirdResponse: Content {
    let success: Bool
    let message: String
}

struct SharedUserDTO: Content {
    let userId: Int64
    let nickname: String
    let avatarUrl: String?
    let role: String
    let sharedAt: Date?
}
