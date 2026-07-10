# 日志模块后端对比报告

## 对比日期：2026-01-26
## 对比范围：旧文档 vs 当前后端实现

---

## 一、API 路由对比

| API | 旧文档 | 当前实现 | 变化 |
|-----|--------|---------|------|
| GET /api/logs | ✅ | ✅ | 无变化 |
| GET /api/logs/:logId | ✅ | ✅ | 无变化 |
| GET /api/logs/bird/:birdId | ❌ 未记录 | ✅ | 新增 |
| POST /api/logs | ✅ | ✅ | 🔧 修复返回 |
| PUT /api/logs/:logId | ✅ | ✅ | 🔧 修复返回 |
| PATCH /api/logs/:logId | ✅ | ✅ | 无变化 |
| DELETE /api/logs/:logId | ✅ | ✅ | 无变化 |
| POST /api/logs/batch | ❌ 未记录 | ✅ | 🔧 新增图片支持 |
| GET /api/logs/weight-trend | ❌ 未记录 | ✅ | 新增 |

---

## 二、核心问题修复

### 🔧 修复 1：createLog 返回 imageUrls

**旧实现（问题）：**
```swift
return BirdLogDTO.from(log, birdName: bird.nickname)  // ❌ 缺少 imageUrls
```

**当前实现：**
```swift
// 返回完整的日志信息，包含图片URL
return BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: input.imageUrls)  // ✅
```

**影响**：前端创建日志后能立即在界面显示图片。

---

### 🔧 修复 2：updateLog 返回 imageUrls

**旧实现（问题）：**
```swift
return BirdLogDTO.from(log, birdName: bird.nickname)  // ❌ 缺少 imageUrls
```

**当前实现：**
```swift
// 查询日志的图片并返回完整信息
let images = try await BirdLogImage.query(on: req.db)
    .filter(\.$logId == logId)
    .sort(\.$sortOrder, .ascending)
    .all()
let imageUrls = images.isEmpty ? nil : images.map { $0.imageUrl }

return BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: imageUrls)  // ✅
```

**影响**：前端更新日志后能正确显示关联图片。

---

### 🔧 修复 3：createLogsBatch 支持图片

**旧实现（问题）：**
```swift
struct CreateLogRequest: Content {
    let birdId: Int64
    let logDate: Date?
    let weight: Double?
    let notes: String?
    // ❌ 没有 imageUrls 字段
}
```

**当前实现：**
```swift
struct CreateLogRequest: Content {
    let birdId: Int64
    let logDate: Date?
    let weight: Double?
    let notes: String?
    let imageUrls: [String]?  // ✅ 添加图片支持
}

// 保存日志图片
if let imageUrls = input.imageUrls, !imageUrls.isEmpty {
    for (index, url) in imageUrls.enumerated() {
        let image = BirdLogImage(logId: log.id!, imageUrl: url, sortOrder: index)
        try await image.save(on: req.db)
    }
}

results.append(BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: input.imageUrls))  // ✅
```

**影响**：批量同步离线日志时可以包含图片。

---

## 三、BirdLogDTO 字段对比

| 字段 | 旧文档 | 当前实现 | 状态 |
|-----|--------|---------|------|
| id | Int64 | Int64 | ✅ 一致 |
| birdId | Int64 | Int64 | ✅ 一致 |
| birdName | String | String | ✅ 一致 |
| logDate | Date | Date | ✅ 一致 |
| weight | Double? | Double? | ✅ 一致 |
| feedAmount | Double? | Double? | ✅ 一致 |
| waterAmount | Double? | Double? | ✅ 一致 |
| mood | String? | String? | ✅ 一致 |
| behavior | String? | String? | ✅ 一致 |
| isMolting | Bool? | Bool? | ✅ 一致 |
| isBreeding | Bool? | Bool? | ✅ 一致 |
| temperature | Double? | Double? | ✅ 一致 |
| humidity | Double? | Double? | ✅ 一致 |
| isCleaned | Bool? | Bool? | ✅ 一致 |
| healthScore | Int? | Int? | ✅ 一致 |
| notes | String? | String? | ✅ 一致 |
| createdAt | Date? | Date? | ✅ 一致 |
| updatedAt | Date? | Date? | ✅ 一致 |
| **imageUrls** | [String]? | [String]? | ✅ 一致（修复后正确返回）|

---

## 四、权限控制对比

| 权限场景 | 旧实现 | 当前实现 |
|---------|--------|---------|
| 鸟主人 | ✅ 完全权限 | ✅ 完全权限 |
| 情侣伴侣 | ✅ 完全权限 | ✅ 完全权限 |
| 共享用户(EDIT) | ✅ 编辑权限 | ✅ 编辑权限 |
| 共享用户(ADMIN) | ✅ 编辑权限 | ✅ 编辑权限 |
| 共享用户(VIEW) | ❌ 无编辑权限 | ❌ 无编辑权限 |

**权限检查方法：** `checkBirdEditAccess(userId:birdId:on:)` - 无变化

---

## 五、getAllLogs 优化

### 关键优化："未知鸟儿"问题修复

**旧实现可能的问题：**
- 只获取用户和伴侣的鸟
- 共享的鸟可能被遗漏，导致日志显示"未知鸟儿"

**当前实现（已修复）：**
```swift
// 获取用户（及伴侣）的所有鸟
let ownedBirds = try await Bird.query(on: req.db)
    .filter(\.$userId ~~ userIds)
    .filter(\.$isDeleted == false)
    .all()

// FIX: 同时获取共享给用户的鸟（"未知鸟儿"问题修复）
let sharedBirdIds = try await BirdShare.query(on: req.db)
    .filter(\.$sharedUserId == userId)
    .filter(\.$status == "ACCEPTED")
    .all()
    .map { $0.birdId }

let sharedBirds = try await Bird.query(on: req.db)
    .filter(\.$id ~~ sharedBirdIds)
    .filter(\.$isDeleted == false)
    .all()

// 合并所有有权限的鸟
let allBirds = ownedBirds + sharedBirds
```

---

## 六、图片处理优化

### 批量查询图片（性能优化）

**当前实现：**
```swift
// FIX: 批量查询所有日志的图片（避免 N+1 查询）
let logIds = logs.compactMap { $0.id }
let allImages = try await BirdLogImage.query(on: req.db)
    .filter(\.$logId ~~ logIds)
    .sort(\.$sortOrder, .ascending)
    .all()

// 构建 logId -> imageUrls 映射
var imageUrlsMap: [Int64: [String]] = [:]
for image in allImages {
    if imageUrlsMap[image.logId] == nil {
        imageUrlsMap[image.logId] = []
    }
    imageUrlsMap[image.logId]?.append(image.imageUrl)
}
```

**优势**：将 N+1 次查询优化为 2 次查询（日志 + 图片）。

---

## 七、总结

### 修复清单

| 序号 | 问题 | 修复状态 |
|------|------|---------|
| 1 | createLog 不返回 imageUrls | ✅ 已修复 |
| 2 | updateLog 不返回 imageUrls | ✅ 已修复 |
| 3 | createLogsBatch 不支持图片 | ✅ 已修复 |
| 4 | getAllLogs 共享鸟的日志显示"未知鸟儿" | ✅ 已修复 |
| 5 | 图片查询 N+1 问题 | ✅ 已优化 |

### 无变化项

- BirdLogDTO 字段结构
- 权限控制逻辑
- API 路由路径
- 日期解析格式

---

**报告生成时间**: 2026-01-26 13:35+08:00
