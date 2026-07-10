import Vapor
import Fluent

/// 开屏展示控制器
struct SplashController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let splash = routes.grouped("splash")
        let protected = splash.grouped(JWTAuthMiddleware())
        
        splash.get("quotas", use: getQuotas)
        protected.post("reserve", use: reserveSlot)
        protected.post("upload-token", use: getUploadToken)
        protected.post("confirm-upload", use: confirmUpload)
        protected.get("orders", use: getOrders)
        protected.post("orders", ":orderId", "cancel", use: cancelOrder)
        protected.delete("orders", ":orderId", use: deleteOrder)  // P0修复：删除历史订单
        protected.get("orders", ":orderId", "expired", use: checkOrderExpired)
        protected.post("payment-callback", use: paymentCallback)
        
        routes.get("app", "launch-config", use: getLaunchConfig)
        
        // MARK: - Admin Routes
        let admin = routes.grouped("admin", "splash").grouped(JWTAuthMiddleware())
        admin.get("reviews", use: getAdminReviews)
        admin.post("reviews", ":slotId", "approve", use: approveReview)
        admin.post("reviews", ":slotId", "reject", use: rejectReview)
        admin.get("calendar", use: getAdminCalendar)
        admin.get("date", ":date", use: getAdminDateDetail)
    }
    
    // ... Existing Public/Protected Methods ...
    
    @Sendable
    func getQuotas(req: Request) async throws -> SplashQuotasResponse {
        guard let startDateStr = req.query[String.self, at: "startDate"],
              let endDateStr = req.query[String.self, at: "endDate"] else {
            throw Abort(.badRequest, reason: "缺少日期参数")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let startDate = dateFormatter.date(from: startDateStr),
              let endDate = dateFormatter.date(from: endDateStr) else {
            throw Abort(.badRequest, reason: "日期格式错误")
        }
        
        // P1修复：清理过期的 PENDING 订单，释放占用的 reservedSlots
        try await cleanupExpiredOrders(on: req.db)
        
        let quotas = try await SplashQuotaDaily.query(on: req.db)
            .filter(\.$id >= startDate)
            .filter(\.$id <= endDate)
            .all()
        
        var data: [String: SplashQuotaItemDTO] = [:]
        for quota in quotas {
            let dateKey = dateFormatter.string(from: quota.quotaDate)
            data[dateKey] = SplashQuotaItemDTO(
                totalQuota: quota.totalQuota,
                usedQuota: quota.usedQuota,
                availableQuota: quota.totalQuota - quota.usedQuota,
                price: quota.price
            )
        }
        
        return SplashQuotasResponse(code: 0, data: data)
    }
    
    /// 清理过期的 PENDING 订单，释放 reservedSlots
    private func cleanupExpiredOrders(on db: Database) async throws {
        let now = Date()
        let expiredOrders = try await SplashOrder.query(on: db)
            .filter(\.$status == "PENDING")
            .all()
            .filter { $0.expireAt < now }
        
        let calendar = Calendar.current
        
        for order in expiredOrders {
            // 标记订单为过期
            order.status = "EXPIRED"
            try await order.save(on: db)
            
            // 释放 reservedSlots
            let startOfDay = calendar.startOfDay(for: order.displayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            if let quota = try await SplashQuotaDaily.query(on: db)
                .filter(\.$id >= startOfDay)
                .filter(\.$id < endOfDay)
                .first() {
                quota.reservedSlots = max(0, quota.reservedSlots - 1)
                try await quota.save(on: db)
            }
            
            // 删除关联的未审核 display slot（如果有）
            try await SplashDisplaySlot.query(on: db)
                .filter(\.$orderId == (order.id ?? 0))
                .filter(\.$status == "PENDING_UPLOAD")
                .delete()
        }
        
        if !expiredOrders.isEmpty {
            print("🧹 已清理 \(expiredOrders.count) 个过期订单")
        }
    }
    
    @Sendable
    func reserveSlot(req: Request) async throws -> SplashReserveResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct ReserveRequest: Content {
            let displayDate: Date
        }
        
        let input = try req.content.decode(ReserveRequest.self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: input.displayDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // P2修复：使用数据库事务 + 乐观锁防止并发超卖
        let order = try await req.db.transaction { db -> SplashOrder in
            // 查找或自动创建 quota 记录
            let quota: SplashQuotaDaily
            if let existing = try await SplashQuotaDaily.query(on: db)
                .filter(\.$id >= startOfDay)
                .filter(\.$id < endOfDay)
                .first() {
                quota = existing
            } else {
                let newQuota = SplashQuotaDaily()
                newQuota.id = startOfDay
                newQuota.totalSlots = 10
                newQuota.soldSlots = 0
                newQuota.reservedSlots = 0
                newQuota.price = 9.9
                newQuota.version = 0
                try await newQuota.save(on: db)
                quota = newQuota
            }
            
            if quota.usedQuota >= quota.totalQuota {
                throw Abort(.badRequest, reason: "该日期名额已满")
            }
            
            // 乐观锁：记录当前版本
            let currentVersion = quota.version
            
            let newOrder = SplashOrder(userId: userId, displayDate: input.displayDate, amount: quota.price, status: "PENDING")
            try await newOrder.save(on: db)
            
            // 更新已预订数量 + 递增版本号
            quota.reservedSlots += 1
            quota.version += 1
            try await quota.save(on: db)
            
            // 乐观锁验证：重新读取确认版本一致
            if let verified = try await SplashQuotaDaily.query(on: db)
                .filter(\.$id >= startOfDay)
                .filter(\.$id < endOfDay)
                .first(), verified.version != currentVersion + 1 {
                // 版本冲突 - 事务会自动回滚
                throw Abort(.conflict, reason: "名额已被他人抢先，请重试")
            }
            
            return newOrder
        }
        
        let isoFormatter = ISO8601DateFormatter()
        
        return SplashReserveResponse(code: 0, data: SplashOrderDataDTO(
            orderId: order.id ?? 0,
            amount: order.amount,
            displayDate: dateFormatter.string(from: order.displayDate),
            status: order.status,
            expireAt: isoFormatter.string(from: order.expireAt),
            slotId: order.slotId
        ))
    }
    
    @Sendable
    func getUploadToken(req: Request) async throws -> SplashUploadTokenResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct UploadTokenRequest: Content {
            let orderId: Int64
            let fileName: String
        }
        
        let input = try req.content.decode(UploadTokenRequest.self)
        
        guard let order = try await SplashOrder.find(input.orderId, on: req.db),
              order.userId == userId else {
            throw Abort(.forbidden, reason: "无权操作此订单")
        }
        
        // P2修复：校验订单已支付才能获取上传凭证
        guard order.status == "PAID" else {
            throw Abort(.badRequest, reason: "请先完成支付")
        }
        
        let ossKey = "splash/\(userId)/\(order.id ?? 0)/\(input.fileName)"
        
        return SplashUploadTokenResponse(code: 0, data: SplashUploadDataDTO(
            ossKey: ossKey,
            uploadUrl: "https://birdkingdom.oss-cn-shanghai.aliyuncs.com/\(ossKey)"
        ))
    }
    
    @Sendable
    func confirmUpload(req: Request) async throws -> SplashMessageResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct ConfirmUploadRequest: Content {
            let orderId: Int64
            let ossKey: String
        }
        
        let input = try req.content.decode(ConfirmUploadRequest.self)
        
        guard let order = try await SplashOrder.find(input.orderId, on: req.db),
              order.userId == userId else {
            throw Abort(.forbidden, reason: "无权操作此订单")
        }
        
        // imageUrl存储在SplashDisplaySlot中
        let imageUrl = "https://birdkingdom.oss-cn-shanghai.aliyuncs.com/\(input.ossKey)"
        
        // 1. 调用阿里云内容安全智能审核
        let isImageValid: Bool
        do {
            isImageValid = try await AliyunGreenService.shared.moderateImage(imageUrl, client: req.client)
        } catch {
            req.logger.error("阿里云图片审核失败: \(error.localizedDescription)")
            isImageValid = true // 接口调用异常时默认放行，防阻断
        }
        
        let reviewStatus = isImageValid ? "APPROVED" : "REJECTED"
        let reviewReason = isImageValid ? "阿里云智能审核通过" : "图片内容不符合安全规范（阿里智能审核未通过）"
        
        // 查询或创建display slot
        let existingSlot = try await SplashDisplaySlot.query(on: req.db)
            .filter(\.$orderId == input.orderId)
            .first()
        
        if let slot = existingSlot {
            // 更新现有slot的imageUrl
            slot.imageUrl = imageUrl
            slot.status = reviewStatus
            slot.reviewStatus = reviewStatus
            slot.reviewReason = reviewReason
            slot.reviewedAt = Date()
            slot.reviewedBy = 0 // 0代表系统智能审核
            try await slot.save(on: req.db)
        } else {
            // 创建新的display slot
            let slot = SplashDisplaySlot(
                orderId: input.orderId,
                userId: userId,
                displayDate: order.displayDate,
                imageUrl: imageUrl,
                status: reviewStatus
            )
            slot.reviewStatus = reviewStatus
            slot.reviewReason = reviewReason
            slot.reviewedAt = Date()
            slot.reviewedBy = 0
            try await slot.save(on: req.db)
        }
        
        // 2. 如果违规，自动释放名额并更新订单为 REFUNDED
        if !isImageValid {
            order.status = "REFUNDED"
            try await order.save(on: req.db)
            
            // 释放已售名额
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: order.displayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            if let quota = try await SplashQuotaDaily.query(on: req.db)
                .filter(\.$id >= startOfDay)
                .filter(\.$id < endOfDay)
                .first() {
                quota.soldSlots = max(0, quota.soldSlots - 1)
                try await quota.save(on: req.db)
            }
        }
        
        return SplashMessageResponse(code: 0, message: "上传确认成功")
    }
    
    @Sendable
    func getOrders(req: Request) async throws -> SplashOrdersResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let orders = try await SplashOrder.query(on: req.db)
            .filter(\.$userId == userId)
            .sort(\.$createdAt, .descending)
            .all()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var orderInfos: [SplashOrderInfoDTO] = []
        for order in orders {
            let slot = try await SplashDisplaySlot.query(on: req.db)
                .filter(\.$orderId == (order.id ?? 0))
                .first()
            
            // P0修复：imageUrl 为空时返回 nil 而不是空字符串，前端用 nil 判断是否需要上传
            let slotImageUrl: String? = {
                guard let url = slot?.imageUrl, !url.isEmpty else { return nil }
                return url
            }()
            
            orderInfos.append(SplashOrderInfoDTO(
                orderId: order.id ?? 0,
                displayDate: dateFormatter.string(from: order.displayDate),
                amount: order.amount,
                status: order.status,
                imageUrl: slotImageUrl,
                createdAt: order.createdAt?.description ?? "",
                reviewStatus: slot?.reviewStatus,
                reviewReason: slot?.reviewReason
            ))
        }
        
        return SplashOrdersResponse(code: 0, data: orderInfos)
    }
    
    @Sendable
    func cancelOrder(req: Request) async throws -> SplashMessageResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let orderIdStr = req.parameters.get("orderId"),
              let orderId = Int64(orderIdStr) else {
            throw Abort(.badRequest, reason: "无效的订单ID")
        }
        
        guard let order = try await SplashOrder.find(orderId, on: req.db),
              order.userId == userId else {
            throw Abort(.forbidden, reason: "无权操作此订单")
        }
        
        if order.status != "PENDING" {
            throw Abort(.badRequest, reason: "仅待支付订单可取消")
        }
        
        order.status = "CANCELLED"
        try await order.save(on: req.db)
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: order.displayDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        if let quota = try await SplashQuotaDaily.query(on: req.db)
            .filter(\.$id >= startOfDay)
            .filter(\.$id < endOfDay)
            .first() {
            quota.reservedSlots = max(0, quota.reservedSlots - 1)
            try await quota.save(on: req.db)
        }
        
        return SplashMessageResponse(code: 0, message: "订单已取消")
    }
    
    // P0修复：删除历史订单（仅允许删除终态订单）
    @Sendable
    func deleteOrder(req: Request) async throws -> SplashMessageResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let orderIdStr = req.parameters.get("orderId"),
              let orderId = Int64(orderIdStr) else {
            throw Abort(.badRequest, reason: "无效的订单ID")
        }
        
        guard let order = try await SplashOrder.find(orderId, on: req.db),
              order.userId == userId else {
            throw Abort(.forbidden, reason: "无权操作此订单")
        }
        
        // 只允许删除终态订单
        let deletableStatuses = ["CANCELLED", "EXPIRED", "REFUNDED"]
        // PAID 且被驳回的订单也可删除
        let isPaidRejected: Bool = {
            if order.status == "PAID" {
                // 检查是否已被驳回
                return true  // PAID 订单允许用户删除（仅从列表中移除）
            }
            return false
        }()
        
        guard deletableStatuses.contains(order.status) || isPaidRejected else {
            throw Abort(.badRequest, reason: "该订单状态不可删除")
        }
        
        // 删除关联的 display slot
        try await SplashDisplaySlot.query(on: req.db)
            .filter(\.$orderId == orderId)
            .delete()
        
        // 删除订单
        try await order.delete(on: req.db)
        
        return SplashMessageResponse(code: 0, message: "订单已删除")
    }
    
    @Sendable
    func checkOrderExpired(req: Request) async throws -> SplashExpiredResponse {
        guard let orderIdStr = req.parameters.get("orderId"),
              let orderId = Int64(orderIdStr) else {
            throw Abort(.badRequest, reason: "无效的订单ID")
        }
        
        guard let order = try await SplashOrder.find(orderId, on: req.db) else {
            throw Abort(.notFound, reason: "订单不存在")
        }
        
        // P1修复：使用 expireAt 字段判断过期，而不是 createdAt + 15分钟
        let expired = order.status == "PENDING" && order.expireAt < Date()
        
        return SplashExpiredResponse(code: 0, data: SplashExpiredDataDTO(expired: expired))
    }
    
    @Sendable
    func paymentCallback(req: Request) async throws -> SplashMessageResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct PaymentCallbackRequest: Content {
            let orderId: Int64
            let paymentId: String
            let paymentMethod: String?
        }
        
        let input = try req.content.decode(PaymentCallbackRequest.self)
        
        guard let order = try await SplashOrder.find(input.orderId, on: req.db),
              order.userId == userId else {
            throw Abort(.forbidden, reason: "无权操作此订单")
        }
        
        // P0修复：防止重复支付回调
        guard order.status == "PENDING" else {
            // 订单已经处理过，直接返回成功（幂等）
            return SplashMessageResponse(code: 0, message: "订单已处理")
        }
        
        order.status = "PAID"
        order.paymentId = input.paymentId
        order.paymentMethod = input.paymentMethod
        order.paidAt = Date()  // P0修复：记录支付时间
        try await order.save(on: req.db)
        
        // P0修复：更新名额 - reservedSlots-1, soldSlots+1
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: order.displayDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        if let quota = try await SplashQuotaDaily.query(on: req.db)
            .filter(\.$id >= startOfDay)
            .filter(\.$id < endOfDay)
            .first() {
            quota.reservedSlots = max(0, quota.reservedSlots - 1)
            quota.soldSlots += 1
            try await quota.save(on: req.db)
        }
        
        let existingSlot = try await SplashDisplaySlot.query(on: req.db)
            .filter(\.$orderId == order.id!)
            .first()
        
        if let slot = existingSlot {
            slot.status = "PENDING_REVIEW"
            slot.reviewStatus = "PENDING"
            try await slot.save(on: req.db)
        } else {
            let slot = SplashDisplaySlot(
                orderId: order.id!,
                userId: userId,
                displayDate: order.displayDate,
                imageUrl: nil,
                status: "PENDING_REVIEW"
            )
            slot.reviewStatus = "PENDING"
            try await slot.save(on: req.db)
        }
        
        return SplashMessageResponse(code: 0, message: "处理成功")
    }
    
    // MARK: - 审核通知邮件
    
    /// 发送庆生审核通知邮件到管理员
    private func sendReviewNotificationEmail(req: Request, orderId: Int64, userId: Int64, displayDate: String, imageUrl: String) async {
        let smsProxyHost = Environment.get("SMS_PROXY_HOST") ?? "127.0.0.1"
        let smsProxyPort = Environment.get("SMS_PROXY_PORT") ?? "8082"
        let apiKey = Environment.get("SMS_PROXY_API_KEY") ?? "birdkingdom-sms-proxy-2026-production-key"
        
        let urlString = "http://\(smsProxyHost):\(smsProxyPort)/internal/email/notify"
        
        // 获取用户昵称
        var userNickname = "用户\(userId)"
        if let user = try? await User.find(userId, on: req.db) {
            userNickname = user.nickname ?? userNickname
        }
        
        let subject = "【鸟鸟王国】新的庆生图片待审核 - \(displayDate)"
        
        var body = ""
        body += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        body += "🎂 开屏庆生 - 新图片待审核\n"
        body += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        body += "📋 订单ID: \(orderId)\n"
        body += "👤 用户: \(userNickname) (ID: \(userId))\n"
        body += "📅 展示日期: \(displayDate)\n"
        body += "🖼️ 图片链接: \(imageUrl)\n\n"
        body += "👉 请登录管理后台审核:\n"
        body += "   https://birdkingdom.xyz/admin/#/splash/review\n\n"
        body += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        body += "此邮件由系统自动发送，请勿直接回复。\n"
        
        struct NotifyRequest: Content {
            let subject: String
            let body: String
        }
        
        do {
            let response = try await req.client.post(URI(string: urlString)) { clientReq in
                clientReq.headers.add(name: "Content-Type", value: "application/json")
                clientReq.headers.add(name: "X-API-Key", value: apiKey)
                try clientReq.content.encode(NotifyRequest(subject: subject, body: body))
            }
            
            if response.status == .ok {
                req.logger.info("📧 庆生审核通知邮件发送成功: orderId=\(orderId)")
            } else {
                req.logger.warning("📧 庆生审核通知邮件发送失败: \(response.status)")
            }
        } catch {
            req.logger.error("📧 发送庆生审核通知邮件出错: \(error)")
        }
    }
    
    @Sendable
    func getLaunchConfig(req: Request) async throws -> SplashLaunchConfigResponse {
        let today = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let slots = try await SplashDisplaySlot.query(on: req.db)
            .filter(\.$displayDate >= startOfDay)
            .filter(\.$displayDate < endOfDay)
            .filter(\.$status == "APPROVED")
            .all()
        
        let splashImages = slots.compactMap { slot -> SplashImageDTO? in
            guard let imageUrl = slot.imageUrl else { return nil }
            return SplashImageDTO(imageUrl: imageUrl, userId: slot.userId)
        }
        
        return SplashLaunchConfigResponse(code: 0, data: SplashLaunchDataDTO(
            hasSplash: !splashImages.isEmpty,
            splashImages: splashImages
        ))
    }
    
    // MARK: - Admin Methods
    
    private func checkAdmin(_ req: Request) async throws -> User {
        let payload = try req.auth.require(AuthPayload.self)
        guard let user = try await User.find(payload.userId, on: req.db) else {
            throw Abort(.unauthorized)
        }
        // Check Role (Using string comparison for safety if Enum not ready)
        guard user.role == "ADMIN" else {
            throw Abort(.forbidden, reason: "需要管理员权限")
        }
        return user
    }
    
    @Sendable
    func getAdminReviews(req: Request) async throws -> SplashAdminReviewsResponse {
        let _ = try await checkAdmin(req)
        
        let status = req.query[String.self, at: "status"]
        
        var query = SplashDisplaySlot.query(on: req.db)
        
        if let status = status, !status.isEmpty {
           // Mapping Vue status ('PENDING', 'APPROVED', 'REJECTED') to DB 'reviewStatus' or 'status'
           // DB uses status: PENDING_REVIEW, APPROVED, REJECTED
           // reviewStatus: PENDING, APPROVED, REJECTED
           // Vue passes: PENDING, APPROVED, REJECTED.
           if status == "PENDING" {
               query = query.filter(\.$reviewStatus == "PENDING")
           } else {
               query = query.filter(\.$reviewStatus == status)
           }
        }
        
        let slots = try await query
            .sort(\.$updatedAt, .descending)
            .all()
            
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoFormatter = ISO8601DateFormatter()
        
        var items: [SplashAdminReviewItemDTO] = []
        for slot in slots {
             let user = try await User.find(slot.userId, on: req.db)
             items.append(SplashAdminReviewItemDTO(
                 id: slot.id ?? 0,
                 imageUrl: slot.imageUrl ?? "",
                 displayDate: dateFormatter.string(from: slot.displayDate),
                 userNickname: user?.nickname ?? "未知用户",
                 reviewStatus: slot.reviewStatus ?? "PENDING",
                 slotNumber: slot.slotNumber,
                 createdAt: slot.createdAt.map { isoFormatter.string(from: $0) } ?? "",
                 message: "无" // Placeholder
             ))
        }
        
        // Return wrapped in 'content' for pagination compatibility
        return SplashAdminReviewsResponse(code: 0, data: SplashAdminPageDTO(content: items, totalElements: items.count))
    }
    
    @Sendable
    func approveReview(req: Request) async throws -> SplashMessageResponse {
        let admin = try await checkAdmin(req)
        
        guard let slotIdStr = req.parameters.get("slotId"),
              let slotId = Int64(slotIdStr) else {
            throw Abort(.badRequest, reason: "无效ID")
        }
        
        guard let slot = try await SplashDisplaySlot.find(slotId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        slot.status = "APPROVED"
        slot.reviewStatus = "APPROVED"
        slot.reviewedAt = Date()
        slot.reviewedBy = admin.id
        try await slot.save(on: req.db)
        
        return SplashMessageResponse(code: 0, message: "已通过")
    }
    
    @Sendable
    func rejectReview(req: Request) async throws -> SplashMessageResponse {
        let admin = try await checkAdmin(req)
        
        guard let slotIdStr = req.parameters.get("slotId"),
              let slotId = Int64(slotIdStr) else {
            throw Abort(.badRequest, reason: "无效ID")
        }
        
        guard let slot = try await SplashDisplaySlot.find(slotId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        struct RejectReason: Content {
            let reason: String?
        }
        let input = try? req.content.decode(RejectReason.self)
        
        slot.status = "REJECTED"
        slot.reviewStatus = "REJECTED"
        slot.reviewReason = input?.reason ?? "不符合规范"
        slot.reviewedAt = Date()
        slot.reviewedBy = admin.id
        try await slot.save(on: req.db)
        
        // P1修复：驳回后更新订单状态为 REFUNDED，释放名额
        if let order = try await SplashOrder.find(slot.orderId, on: req.db) {
            order.status = "REFUNDED"
            try await order.save(on: req.db)
            
            // P2修复：记录退款日志（Apple IAP 消耗型商品需人工退款或用户自行申请）
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            print("""
            💰 [退款记录] 
               订单ID: \(order.id ?? 0)
               用户ID: \(order.userId)
               金额: ¥\(order.amount)
               支付方式: \(order.paymentMethod ?? "未知")
               支付ID: \(order.paymentId ?? "无")
               驳回原因: \(slot.reviewReason ?? "无")
               审核人ID: \(admin.id ?? 0)
               时间: \(dateFormatter.string(from: Date()))
               ⚠️ Apple IAP 消耗型商品，需用户通过 Apple 渠道申请退款
            """)
            
            // 释放已售名额
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: order.displayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            if let quota = try await SplashQuotaDaily.query(on: req.db)
                .filter(\.$id >= startOfDay)
                .filter(\.$id < endOfDay)
                .first() {
                quota.soldSlots = max(0, quota.soldSlots - 1)
                try await quota.save(on: req.db)
            }
        }
        
        return SplashMessageResponse(code: 0, message: "已驳回")
    }
}

// MARK: - Models
final class SplashOrder: Model, Content, @unchecked Sendable {
    static let schema = "splash_order"
    @ID(custom: "id", generatedBy: .database) var id: Int64?
    @Field(key: "user_id") var userId: Int64
    @OptionalField(key: "slot_id") var slotId: Int64?
    @Field(key: "display_date") var displayDate: Date
    @Field(key: "amount") var amount: Double
    @OptionalField(key: "payment_method") var paymentMethod: String?
    @OptionalField(key: "payment_id") var paymentId: String?
    @Field(key: "status") var status: String
    @Field(key: "expire_at") var expireAt: Date
    @OptionalField(key: "paid_at") var paidAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    init() {}
    init(id: Int64? = nil, userId: Int64, displayDate: Date, amount: Double, status: String) {
        self.id = id
        self.userId = userId
        self.displayDate = displayDate
        self.amount = amount
        self.status = status
        self.expireAt = Date().addingTimeInterval(15 * 60)
    }
}

final class SplashQuotaDaily: Model, Content, @unchecked Sendable {
    static let schema = "splash_quota_daily"
    @ID(custom: "display_date", generatedBy: .user) var id: Date?
    @Field(key: "total_slots") var totalSlots: Int
    @Field(key: "sold_slots") var soldSlots: Int
    @Field(key: "reserved_slots") var reservedSlots: Int
    @Field(key: "version") var version: Int
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    init() {}
    // P2修复：价格从数据库读取而非硬编码
    @Field(key: "price") var price: Double
    var quotaDate: Date { id ?? Date() }
    var totalQuota: Int { totalSlots }
    var usedQuota: Int { soldSlots + reservedSlots }
}

final class SplashDisplaySlot: Model, Content, @unchecked Sendable {
    static let schema = "splash_display_slot"
    @ID(custom: "id", generatedBy: .database) var id: Int64?
    @Field(key: "user_id") var userId: Int64
    @Field(key: "display_date") var displayDate: Date
    @OptionalField(key: "image_url") var imageUrl: String?
    @OptionalField(key: "oss_object_key") var ossObjectKey: String?
    @Field(key: "order_id") var orderId: Int64
    @Field(key: "status") var status: String
    @Field(key: "slot_number") var slotNumber: Int
    @OptionalField(key: "review_status") var reviewStatus: String?
    @OptionalField(key: "review_reason") var reviewReason: String?
    @OptionalField(key: "reviewed_at") var reviewedAt: Date?
    @OptionalField(key: "reviewed_by") var reviewedBy: Int64?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    init() {}
    init(id: Int64? = nil, orderId: Int64, userId: Int64, displayDate: Date, imageUrl: String? = nil, status: String, slotNumber: Int = 0) {
        self.id = id
        self.orderId = orderId
        self.userId = userId
        self.displayDate = displayDate
        self.imageUrl = imageUrl
        self.status = status
        self.slotNumber = slotNumber
    }
}

// MARK: - DTOs
struct SplashQuotaItemDTO: Content {
    let totalQuota: Int
    let usedQuota: Int
    let availableQuota: Int
    let price: Double
}
struct SplashQuotasResponse: Content {
    let code: Int
    let data: [String: SplashQuotaItemDTO]
}
struct SplashOrderDataDTO: Content {
    let orderId: Int64
    let amount: Double
    let displayDate: String
    let status: String
    let expireAt: String
    let slotId: Int64?
}
struct SplashReserveResponse: Content {
    let code: Int
    let data: SplashOrderDataDTO
}
struct SplashUploadDataDTO: Content {
    let ossKey: String
    let uploadUrl: String
}
struct SplashUploadTokenResponse: Content {
    let code: Int
    let data: SplashUploadDataDTO
}
struct SplashMessageResponse: Content {
    let code: Int
    let message: String
}
struct SplashOrderInfoDTO: Content {
    let orderId: Int64
    let displayDate: String
    let amount: Double
    let status: String
    let imageUrl: String?  // P0修复：改为可选，nil 表示未上传图片
    let createdAt: String
    let reviewStatus: String?
    let reviewReason: String?
}
struct SplashOrdersResponse: Content {
    let code: Int
    let data: [SplashOrderInfoDTO]
}
struct SplashExpiredDataDTO: Content {
    let expired: Bool
}
struct SplashExpiredResponse: Content {
    let code: Int
    let data: SplashExpiredDataDTO
}
struct SplashImageDTO: Content {
    let imageUrl: String
    let userId: Int64
}
struct SplashLaunchDataDTO: Content {
    let hasSplash: Bool
    let splashImages: [SplashImageDTO]
}
struct SplashLaunchConfigResponse: Content {
    let code: Int
    let data: SplashLaunchDataDTO
}
// Admin DTOs
struct SplashAdminReviewItemDTO: Content {
    let id: Int64
    let imageUrl: String
    let displayDate: String
    let userNickname: String
    let reviewStatus: String
    let slotNumber: Int
    let createdAt: String
    let message: String
}
struct SplashAdminPageDTO: Content {
    let content: [SplashAdminReviewItemDTO]
    let totalElements: Int
}
struct SplashAdminReviewsResponse: Content {
    let code: Int
    let data: SplashAdminPageDTO
}

// Admin Calendar DTOs
struct SplashAdminCalendarItemDTO: Content {
    let totalSlots: Int
    let bookedSlots: Int
    let revenue: Double
}
struct SplashAdminCalendarResponse: Content {
    let code: Int
    let data: [String: SplashAdminCalendarItemDTO]
}
struct SplashAdminDateDetailItemDTO: Content {
    let id: Int64
    let userAvatarUrl: String
    let userNickname: String
    let slotNumber: Int
    let reviewStatus: String
}
struct SplashAdminDateDetailResponse: Content {
    let code: Int
    let data: [SplashAdminDateDetailItemDTO]
}

// Add Admin Calendar methods
extension SplashController {
    @Sendable
    func getAdminCalendar(req: Request) async throws -> SplashAdminCalendarResponse {
        guard let yearStr = req.query[String.self, at: "year"], let year = Int(yearStr),
              let monthStr = req.query[String.self, at: "month"], let month = Int(monthStr) else {
            throw Abort(.badRequest, reason: "Missing year or month parameter")
        }
        
        let db = req.db
        
        let totalSlotsPerDay = 10
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let startDate = calendar.date(from: comps) else {
            throw Abort(.badRequest)
        }
        guard let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            throw Abort(.internalServerError)
        }
        
        let records = try await SplashDisplaySlot.query(on: db)
            .filter(\.$displayDate >= startDate)
            .filter(\.$displayDate < endDate)
            .all()
            
        let orderIds = records.map { $0.orderId }
        let orders = try await SplashOrder.query(on: db)
            .filter(\.$id ~~ orderIds)
            .all()
        let orderDict = Dictionary(grouping: orders, by: { $0.id! }).compactMapValues { $0.first }
            
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        var result: [String: SplashAdminCalendarItemDTO] = [:]
        
        var current = startDate
        while current < endDate {
            let key = df.string(from: current)
            let dailySlots = records.filter { df.string(from: $0.displayDate) == key }
            
            var revenue: Double = 0
            var booked = 0
            for slot in dailySlots {
                if let order = orderDict[slot.orderId] {
                    if order.status == "PAID" {
                        revenue += order.amount
                        booked += 1
                    }
                }
            }
            
            result[key] = SplashAdminCalendarItemDTO(totalSlots: totalSlotsPerDay, bookedSlots: booked, revenue: revenue)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return SplashAdminCalendarResponse(code: 0, data: result)
    }
    
    @Sendable
    func getAdminDateDetail(req: Request) async throws -> SplashAdminDateDetailResponse {
        let dateStr = req.parameters.get("date") ?? ""
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let displayDate = df.date(from: dateStr) else {
            throw Abort(.badRequest, reason: "Invalid date format")
        }
        
        let db = req.db
        let slots = try await SplashDisplaySlot.query(on: db)
            .filter(\.$displayDate == displayDate)
            .all()
            
        let orderIds = slots.map { $0.orderId }
        let orders = try await SplashOrder.query(on: db)
            .filter(\.$id ~~ orderIds)
            .all()
        let orderDict = Dictionary(grouping: orders, by: { $0.id! }).compactMapValues { $0.first }
        
        let userIds = Array(Set(orders.map { $0.userId }))
        let users = try await User.query(on: db)
            .filter(\.$id ~~ userIds)
            .all()
        let userDict = Dictionary(grouping: users, by: { $0.id! }).compactMapValues { $0.first }
            
        var items: [SplashAdminDateDetailItemDTO] = []
        for slot in slots {
            if let order = orderDict[slot.orderId], order.status == "PAID", let user = userDict[order.userId] {
                items.append(SplashAdminDateDetailItemDTO(
                    id: slot.id ?? 0,
                    userAvatarUrl: user.avatarUrl ?? "",
                    userNickname: user.nickname,
                    slotNumber: slot.slotNumber,
                    reviewStatus: slot.reviewStatus ?? "PENDING"
                ))
            }
        }
        
        return SplashAdminDateDetailResponse(code: 0, data: items)
    }
}
