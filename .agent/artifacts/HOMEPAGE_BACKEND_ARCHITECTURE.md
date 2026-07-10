# 首页后端架构完整设计

## 作者：资深架构师视角
## 日期：2026-01-26

---

## 一、首页功能模块

根据前端 `BirdListView.swift` 分析，首页包含以下功能模块：

| 模块 | 功能 | 后端 Controller |
|-----|------|----------------|
| 我的鸟舍 | 显示用户的鸟儿列表（含伴侣的鸟） | `BirdController` |
| 日志 | 显示鸟儿日志 | `BirdLogController` |
| 体重趋势 | 显示体重变化图表 | `BirdLogController.getWeightTrend` |
| 记录 | 产蛋/洗澡记录 | `BirdRecordController` |
| 支出管理 | 养鸟支出统计 | `ExpenseController` |
| 近期提醒 | 用户设置的提醒 | `ReminderController` |

---

## 二、后端 API 清单

### 2.1 鸟儿管理 (`/api/birds`)

| 方法 | 路径 | 功能 |
|-----|------|------|
| GET | `/api/birds` | 获取我的鸟儿列表（含伴侣的鸟） |
| GET | `/api/birds/:birdId` | 获取单只鸟儿详情 |
| POST | `/api/birds` | 添加鸟儿 |
| PUT | `/api/birds/:birdId` | 更新鸟儿 |
| DELETE | `/api/birds/:birdId` | 删除鸟儿（软删除） |
| POST | `/api/birds/:birdId/restore` | 恢复已删除的鸟儿 |
| GET | `/api/birds/deleted` | 获取回收站中的鸟儿 |
| DELETE | `/api/birds/:birdId/permanent` | 永久删除鸟儿 |
| POST | `/api/birds/:birdId/death` | 标记鸟儿死亡 |
| GET | `/api/birds/active` | 获取活跃的鸟（非回收站） |
| POST | `/api/birds/:birdId/share` | 共享鸟儿给他人 |
| GET | `/api/birds/:birdId/shared-users` | 获取共享用户列表 |
| DELETE | `/api/birds/:birdId/shared-users/:userId` | 移除共享用户 |
| PUT | `/api/birds/:birdId/lost` | 更新丢失状态 |

### 2.2 日志管理 (`/api/logs`)

| 方法 | 路径 | 功能 |
|-----|------|------|
| GET | `/api/logs` | 获取当前用户的所有日志 |
| GET | `/api/logs/:logId` | 获取单条日志 |
| GET | `/api/logs/bird/:birdId` | 获取某只鸟的日志 |
| POST | `/api/logs` | 创建日志 |
| PUT | `/api/logs/:logId` | 更新日志（完整更新） |
| PATCH | `/api/logs/:logId` | 部分更新日志（右滑编辑） |
| DELETE | `/api/logs/:logId` | 删除日志 |
| POST | `/api/logs/batch` | 批量创建日志 |
| GET | `/api/logs/weight-trend` | 获取体重趋势 |

### 2.3 生理周期记录 (`/api/birds/:birdId/cycles`)

| 方法 | 路径 | 功能 |
|-----|------|------|
| GET | `/api/birds/:birdId/cycles` | 获取某鸟所有记录 |
| POST | `/api/birds/:birdId/cycles` | 新增记录（产蛋/洗澡） |
| DELETE | `/api/records/:cycleId` | 删除记录 |

### 2.4 支出管理 (`/api/expenses`)

| 方法 | 路径 | 功能 |
|-----|------|------|
| GET | `/api/expenses` | 获取支出列表 |
| GET | `/api/expenses/stats` | 获取支出统计 |
| POST | `/api/expenses` | 添加支出 |
| PUT | `/api/expenses/:expenseId` | 更新支出 |
| DELETE | `/api/expenses/:expenseId` | 删除支出 |

### 2.5 提醒管理 (`/api/reminders`)

| 方法 | 路径 | 功能 |
|-----|------|------|
| GET | `/api/reminders` | 获取所有提醒 |
| GET | `/api/reminders/enabled` | 获取已启用的提醒 |
| GET | `/api/reminders/:reminderId` | 获取单条提醒 |
| POST | `/api/reminders` | 创建提醒 |
| PUT | `/api/reminders/:reminderId` | 更新提醒 |
| POST | `/api/reminders/:reminderId/toggle` | 切换提醒启用状态 |
| DELETE | `/api/reminders/:reminderId` | 删除提醒 |

---

## 三、数据传输对象（DTO）

### 3.1 BirdDTO

```swift
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
    
    // 扩展字段
    let ageMonths: Int?
    let deletedAt: Date?
    let ownerId: Int64?
    let ownerName: String?        // 情侣共享时显示伴侣名称
    let isShared: Bool?
    let sharedWith: [BirdCoOwnerDTO]?
    let shareRole: String?
    let isOwner: Bool?            // 是否是原始主人
    let isCoupleShared: Bool?     // 是否是情侣共享
}
```

### 3.2 BirdLogDTO

```swift
struct BirdLogDTO: Content {
    let id: Int64
    let birdId: Int64
    let birdName: String          // ✅ 后端保证填充
    let logDate: Date
    let weight: Double?
    let feedAmount: Double?
    let waterAmount: Double?
    let healthScore: Int?
    let mood: String?
    let behavior: String?
    let isMolting: Bool?
    let isBreeding: Bool?
    let temperature: Double?
    let humidity: Double?
    let isCleaned: Bool?
    let notes: String?
    let imageUrls: [String]?      // ✅ 后端保证填充
    let createdAt: Date?
    let updatedAt: Date?
}
```

### 3.3 其他 DTO

- `ReminderDTO`: 提醒数据
- `ExpenseDTO`: 支出数据
- `ExpenseStatsDTO`: 支出统计
- `BirdRecordDTO`: 生理周期记录
- `WeightTrendDTO`: 体重趋势

---

## 四、权限控制

### 4.1 鸟儿访问权限

后端通过 `checkBirdAccess` 和 `checkBirdEditAccess` 方法控制权限：

1. **鸟主人**：完全权限
2. **情侣伴侣**：完全权限（通过 `couplePartnerId` 判断）
3. **共享用户**：
   - `EDIT`/`ADMIN` 角色：编辑权限
   - `VIEW` 角色：只读权限

### 4.2 日志权限

日志权限继承自关联鸟儿的权限：
- 能访问鸟儿 → 能查看该鸟的日志
- 能编辑鸟儿 → 能编辑该鸟的日志

---

## 五、已修复的问题

### 5.1 日志返回完整信息

**问题**：`createLog` 和 `updateLog` 返回时没有包含 `imageUrls`

**修复**：
- `createLog`: 返回时包含 `input.imageUrls`
- `updateLog`: 查询日志图片后返回
- `createLogsBatch`: 支持图片并返回

### 5.2 批量创建日志支持图片

**问题**：`createLogsBatch` 不支持图片

**修复**：
- 添加 `imageUrls` 参数
- 保存图片到 `bird_log_images` 表

---

## 六、数据库表结构

### 6.1 核心表

| 表名 | 说明 |
|-----|------|
| `birds` | 鸟儿信息 |
| `bird_logs` | 鸟儿日志 |
| `bird_log_images` | 日志图片 |
| `bird_record` | 生理周期记录 |
| `bird_shares` | 鸟儿共享 |
| `expenses` | 支出记录 |
| `reminders` | 提醒 |
| `users` | 用户 |

### 6.2 关键字段

**birds 表**：
- `user_id`: 鸟主人ID
- `is_deleted`: 是否软删除
- `is_lost`: 是否丢失

**bird_logs 表**：
- `bird_id`: 关联鸟ID
- `log_date`: 日志日期
- `weight`: 体重

**bird_log_images 表**：
- `log_id`: 关联日志ID
- `image_url`: 图片URL
- `sort_order`: 排序

---

## 七、API 响应格式

### 7.1 成功响应

```json
{
    "id": 123,
    "birdId": 1,
    "birdName": "小绿",
    "logDate": "2026-01-26T10:00:00Z",
    "notes": "今天状态很好",
    "imageUrls": ["url1", "url2"]
}
```

### 7.2 错误响应

```json
{
    "error": true,
    "reason": "鸟儿不存在"
}
```

---

## 八、总结

后端首页功能现已完整实现：

1. ✅ **鸟儿管理**：CRUD、共享、丢失状态、情侣共享
2. ✅ **日志管理**：CRUD、批量创建、图片支持、体重趋势
3. ✅ **生理周期**：产蛋/洗澡记录
4. ✅ **支出管理**：CRUD、统计
5. ✅ **提醒管理**：CRUD、启用/禁用

**关键保证**：
- `birdName` 在所有日志 API 响应中都会填充
- `imageUrls` 在创建/更新日志时都会正确返回
- 权限控制覆盖所有数据访问
