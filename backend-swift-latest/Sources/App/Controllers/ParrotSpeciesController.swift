import Vapor
import Fluent

/// 鸟类品种控制器
struct ParrotSpeciesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let species = routes.grouped("species")
        
        // 获取所有品种（按分类分组）
        species.get(use: getAllSpecies)
        
        // 获取所有分类列表
        species.get("categories", use: getCategories)
        
        // 根据分类获取品种
        species.get("category", ":category", use: getByCategory)
        
        // 根据名称查找品种
        species.get("by-name", use: getByName)
        
        // 搜索品种
        species.get("search", use: searchSpecies)
    }
    
    // MARK: - 获取所有品种
    @Sendable
    func getAllSpecies(req: Request) async throws -> [String: [ParrotSpeciesDTO]] {
        let allSpecies = try await ParrotSpecies.query(on: req.db)
            .sort(\.$category, .ascending)
            .sort(\.$name, .ascending)
            .all()
        
        // 按分类分组
        var grouped: [String: [ParrotSpeciesDTO]] = [:]
        for species in allSpecies {
            let category = species.category ?? "其他"
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(ParrotSpeciesDTO.from(species))
        }
        
        return grouped
    }
    
    // MARK: - 获取所有分类
    @Sendable
    func getCategories(req: Request) async throws -> [String] {
        let allSpecies = try await ParrotSpecies.query(on: req.db).all()
        let categories = Set(allSpecies.compactMap { $0.category })
        return Array(categories).sorted()
    }
    
    // MARK: - 根据分类获取品种
    @Sendable
    func getByCategory(req: Request) async throws -> [ParrotSpeciesDTO] {
        guard let category = req.parameters.get("category") else {
            throw Abort(.badRequest, reason: "缺少分类参数")
        }
        
        let species = try await ParrotSpecies.query(on: req.db)
            .filter(\.$category == category)
            .sort(\.$name, .ascending)
            .all()
        
        return species.map { ParrotSpeciesDTO.from($0) }
    }
    
    // MARK: - 根据名称查找品种
    @Sendable
    func getByName(req: Request) async throws -> ParrotSpeciesDTO {
        guard let name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest, reason: "缺少名称参数")
        }
        
        guard let species = try await ParrotSpecies.query(on: req.db)
            .filter(\.$name == name)
            .first() else {
            throw Abort(.notFound, reason: "品种不存在")
        }
        
        return ParrotSpeciesDTO.from(species)
    }
    
    // MARK: - 搜索品种
    @Sendable
    func searchSpecies(req: Request) async throws -> [ParrotSpeciesDTO] {
        guard let keyword = req.query[String.self, at: "keyword"] else {
            throw Abort(.badRequest, reason: "缺少搜索关键词")
        }
        
        let species = try await ParrotSpecies.query(on: req.db)
            .filter(\.$name ~~ keyword)
            .all()
        
        return species.map { ParrotSpeciesDTO.from($0) }
    }
}

// MARK: - 品种模型
final class ParrotSpecies: Model, Content, @unchecked Sendable {
    static let schema = "parrot_species"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "category")
    var category: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "weight_min")
    var weightMin: Double
    
    @Field(key: "weight_max")
    var weightMax: Double
    
    @OptionalField(key: "molting_duration_min")
    var moltingDurationMin: Int?
    
    @OptionalField(key: "molting_duration_max")
    var moltingDurationMax: Int?
    
    @OptionalField(key: "molting_cycle_min")
    var moltingCycleMin: Int?
    
    @OptionalField(key: "molting_cycle_max")
    var moltingCycleMax: Int?
    
    @OptionalField(key: "incubation_days")
    var incubationDays: Int?
    
    @OptionalField(key: "clutch_size_min")
    var clutchSizeMin: Int?
    
    @OptionalField(key: "clutch_size_max")
    var clutchSizeMax: Int?
    
    @OptionalField(key: "estrus_cycle_min")
    var estrusCycleMin: Int?
    
    @OptionalField(key: "estrus_cycle_max")
    var estrusCycleMax: Int?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
}

// MARK: - DTO
struct ParrotSpeciesDTO: Content {
    let id: Int64
    let name: String
    let category: String?
    let weightMin: Double?
    let weightMax: Double?
    let moltingDurationMin: Int?
    let moltingDurationMax: Int?
    let moltingCycleMin: Int?
    let moltingCycleMax: Int?
    let incubationDays: Int?
    let clutchSizeMin: Int?
    let clutchSizeMax: Int?
    let estrusCycleMin: Int?
    let estrusCycleMax: Int?
    
    static func from(_ species: ParrotSpecies) -> ParrotSpeciesDTO {
        ParrotSpeciesDTO(
            id: species.id ?? 0,
            name: species.name,
            category: species.category,
            weightMin: species.weightMin,
            weightMax: species.weightMax,
            moltingDurationMin: species.moltingDurationMin,
            moltingDurationMax: species.moltingDurationMax,
            moltingCycleMin: species.moltingCycleMin,
            moltingCycleMax: species.moltingCycleMax,
            incubationDays: species.incubationDays,
            clutchSizeMin: species.clutchSizeMin,
            clutchSizeMax: species.clutchSizeMax,
            estrusCycleMin: species.estrusCycleMin,
            estrusCycleMax: species.estrusCycleMax
        )
    }
}
