import Vapor
import Fluent

/// 共享邀请控制器
struct InvitationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let share = routes.grouped("share")
        let invitations = share.grouped("invitations")
        let protected = invitations.grouped(JWTAuthMiddleware())
        
        protected.get("pending", use: getPendingInvitations)
        protected.post(":invitationId", "accept", use: acceptInvitation)
        protected.post(":invitationId", "reject", use: rejectInvitation)
    }
    
    @Sendable
    func getPendingInvitations(req: Request) async throws -> [InvitationItemDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let invitations = try await BirdShareInvitation.query(on: req.db)
            .filter(\.$inviteeId == userId)
            .filter(\.$status == "PENDING")
            .all()
        
        var results: [InvitationItemDTO] = []
        for invitation in invitations {
            var birdName = "未知"
            var birdSpecies: String? = nil
            if let bird = try await Bird.find(invitation.birdId, on: req.db) {
                birdName = bird.nickname
                birdSpecies = bird.species
            }
            
            var inviterName = "未知用户"
            if let inviter = try await User.find(invitation.inviterId, on: req.db) {
                inviterName = inviter.nickname
            }
            
            results.append(InvitationItemDTO(
                id: invitation.id ?? 0,
                birdId: invitation.birdId,
                birdName: birdName,
                birdSpecies: birdSpecies,
                inviterName: inviterName,
                role: invitation.role,
                createdAt: invitation.createdAt
            ))
        }
        
        return results
    }
    
    @Sendable
    func acceptInvitation(req: Request) async throws -> InvitationActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let invitationIdStr = req.parameters.get("invitationId"),
              let invitationId = Int64(invitationIdStr) else {
            throw Abort(.badRequest, reason: "无效的邀请ID")
        }
        
        guard let invitation = try await BirdShareInvitation.find(invitationId, on: req.db) else {
            return InvitationActionResponse(success: false, message: "邀请不存在")
        }
        
        if invitation.inviteeId != userId {
            return InvitationActionResponse(success: false, message: "无权操作此邀请")
        }
        
        if invitation.status != "PENDING" {
            return InvitationActionResponse(success: false, message: "邀请已处理")
        }
        
        invitation.status = "ACCEPTED"
        try await invitation.save(on: req.db)
        
        let share = BirdShare(birdId: invitation.birdId, ownerId: invitation.inviterId, sharedUserId: userId, role: invitation.role, status: "ACCEPTED")
        try await share.save(on: req.db)
        
        return InvitationActionResponse(success: true, message: "已接受邀请")
    }
    
    @Sendable
    func rejectInvitation(req: Request) async throws -> InvitationActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let invitationIdStr = req.parameters.get("invitationId"),
              let invitationId = Int64(invitationIdStr) else {
            throw Abort(.badRequest, reason: "无效的邀请ID")
        }
        
        guard let invitation = try await BirdShareInvitation.find(invitationId, on: req.db) else {
            return InvitationActionResponse(success: false, message: "邀请不存在")
        }
        
        if invitation.inviteeId != userId {
            return InvitationActionResponse(success: false, message: "无权操作此邀请")
        }
        
        if invitation.status != "PENDING" {
            return InvitationActionResponse(success: false, message: "邀请已处理")
        }
        
        invitation.status = "REJECTED"
        try await invitation.save(on: req.db)
        
        return InvitationActionResponse(success: true, message: "已拒绝邀请")
    }
}

// MARK: - Models
final class BirdShareInvitation: Model, Content, @unchecked Sendable {
    static let schema = "bird_share_invitation"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "bird_id")
    var birdId: Int64
    
    @Field(key: "inviter_id")
    var inviterId: Int64
    
    @Field(key: "invitee_id")
    var inviteeId: Int64
    
    @Field(key: "role")
    var role: String
    
    @Field(key: "status")
    var status: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
}

// 注意: BirdShare 模型定义在 Models/AdditionalModels.swift 中
// 这里的 BirdShareInvitation 使用的是 bird_share_invitation 表
// 而实际的 BirdShare 使用 bird_shares 表

// MARK: - DTOs
struct InvitationItemDTO: Content {
    let id: Int64
    let birdId: Int64
    let birdName: String
    let birdSpecies: String?  // 🔧 FIX: 添加鸟类品种字段
    let inviterName: String
    let role: String
    let createdAt: Date?
}

struct InvitationActionResponse: Content {
    let success: Bool
    let message: String
}
