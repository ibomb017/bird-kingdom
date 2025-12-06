import Foundation

// MARK: - 鸟类食物完整数据库
// 数据来源：AAV(Association of Avian Veterinarians)、Lafeber兽医研究、Harrison's Bird Foods、
// Avian Medicine: Principles and Application、Clinical Avian Medicine等权威资料

extension BirdFood {
    static let allFoods: [BirdFood] = 
        fruitsFoods + vegetablesFoods + grainsFoods + proteinsFoods + 
        nutsFoods + herbsFoods + humanFoodsFoods + drinksFoods + 
        seasoningsFoods + snacksFoods + othersFoods
}
