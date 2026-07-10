import Foundation

/// 鸟类品种（含体重范围和生理周期参考值）
struct BirdSpecies: Identifiable, Codable {
    let id: Int
    let category: String
    let name: String
    let weightMin: Double
    let weightMax: Double
    let moltingDurationMin: Int?
    let moltingDurationMax: Int?
    let moltingCycleMin: Int?
    let moltingCycleMax: Int?
    let incubationDays: Int?
    let clutchSizeMin: Int?
    let clutchSizeMax: Int?
    let estrusCycleMin: Int?
    let estrusCycleMax: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case category
        case name
        case weightMin
        case weightMax
        case moltingDurationMin
        case moltingDurationMax
        case moltingCycleMin
        case moltingCycleMax
        case incubationDays
        case clutchSizeMin
        case clutchSizeMax
        case estrusCycleMin
        case estrusCycleMax
    }
}

/// 品种分类（用于分组显示）
struct SpeciesCategory: Identifiable {
    let id: String
    let name: String
    let species: [BirdSpecies]
    
    init(name: String, species: [BirdSpecies]) {
        self.id = name
        self.name = name
        self.species = species
    }
}
