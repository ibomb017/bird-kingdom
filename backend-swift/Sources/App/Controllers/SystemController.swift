import Vapor
import Fluent

struct SystemConfigResponse: Content {
    let splashSlotsPerDay: Int
    let splashPrice: Int
}

struct UpdateSystemConfigRequest: Content {
    let splash_slots_per_day: Int
    let splash_price: Int
}

/// 系统配置控制器
struct SystemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let systemGroup = routes.grouped("system")
        let protected = systemGroup.grouped(JWTAuthMiddleware(), StatsAdminMiddleware())
        
        protected.get("config", use: getConfig)
        protected.put("config", use: updateConfig)
    }
    
    @Sendable
    func getConfig(req: Request) async throws -> StatsApiResponse<SystemConfigResponse> {
        let db = req.db
        
        // Default values
        var slots = 10
        var price = 99
        
        if let slotsConfig = try await SystemConfig.query(on: db).filter(\.$configKey == "splash.slots_per_day").first() {
            if let val = Int(slotsConfig.configValue) {
                slots = val
            }
        }
        
        if let priceConfig = try await SystemConfig.query(on: db).filter(\.$configKey == "splash.price").first() {
            // Vue frontend says "splashPrice 990 = ¥9.90", meaning it treats it as currency in cents or something, but the db has 99.
            if let val = Int(priceConfig.configValue) {
                price = val
            }
        }
        
        return StatsApiResponse(data: SystemConfigResponse(splashSlotsPerDay: slots, splashPrice: price))
    }
    
    @Sendable
    func updateConfig(req: Request) async throws -> StatsApiResponse<String> {
        let updateReq = try req.content.decode(UpdateSystemConfigRequest.self)
        let db = req.db
        
        if let slotsConfig = try await SystemConfig.query(on: db).filter(\.$configKey == "splash.slots_per_day").first() {
            slotsConfig.configValue = String(updateReq.splash_slots_per_day)
            try await slotsConfig.save(on: db)
        } else {
            let newSlots = SystemConfig()
            newSlots.configKey = "splash.slots_per_day"
            newSlots.configValue = String(updateReq.splash_slots_per_day)
            newSlots.valueType = "NUMBER"
            newSlots.category = "SPLASH"
            newSlots.isPublic = false
            try await newSlots.save(on: db)
        }
        
        if let priceConfig = try await SystemConfig.query(on: db).filter(\.$configKey == "splash.price").first() {
            priceConfig.configValue = String(updateReq.splash_price)
            try await priceConfig.save(on: db)
        } else {
            let newPrice = SystemConfig()
            newPrice.configKey = "splash.price"
            newPrice.configValue = String(updateReq.splash_price)
            newPrice.valueType = "NUMBER"
            newPrice.category = "SPLASH"
            newPrice.isPublic = false
            try await newPrice.save(on: db)
        }
        
        return StatsApiResponse(data: "Success")
    }
}
