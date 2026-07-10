# Admin Web 功能审计报告

## 审计时间
2025-12-29 17:47

## 功能模块清单

### 1. 用户管理 (User Management)
**前端页面：**
- [x] 用户列表 (list.vue)
- [x] VIP管理 (vip.vue)
- [x] 情侣管理 (couples.vue, couple.vue)
- [x] 用户关系 (relations.vue)
- [x] 通知管理 (notifications.vue)
- [x] 反馈管理 (feedback.vue)

**后端Controller：** UserController.java

**需要的API：**
- [ ] GET /users - 获取用户列表
- [ ] GET /users/{id} - 获取用户详情
- [ ] PUT /users/{id} - 更新用户信息
- [ ] DELETE /users/{id} - 删除用户
- [ ] POST /users/{id}/vip - 赠送VIP
- [ ] GET /couples - 获取情侣列表
- [ ] POST /couples/{id}/unbind - 解绑情侣

---

### 2. 鸟类管理 (Bird Management)
**前端页面：**
- [ ] 鸟类列表
- [ ] 日志管理
- [ ] 品种管理

**后端Controller：** BirdController.java

**需要的API：**
- [ ] GET /birds - 获取鸟类列表
- [ ] GET /birds/{id} - 获取鸟类详情
- [ ] DELETE /birds/{id} - 删除鸟类
- [ ] GET /logs - 获取日志列表
- [ ] DELETE /logs/{id} - 删除日志

---

### 3. 论坛管理 (Forum Management)
**前端页面：**
- [x] 帖子列表 (posts.vue)
- [x] 评论管理 (comments.vue)
- [x] 举报管理 (reports.vue)

**后端Controller：** ForumController.java

**需要的API：**
- [x] GET /forum/posts - 获取帖子列表
- [x] GET /forum/posts/{id} - 获取帖子详情
- [x] DELETE /forum/posts/{id} - 删除帖子
- [x] GET /forum/comments - 获取评论列表
- [x] DELETE /forum/comments/{id} - 删除评论
- [x] GET /forum/reports - 获取举报列表
- [x] POST /forum/reports/{id}/handle - 处理举报

---

### 4. 百科管理 (Encyclopedia Management)
**前端页面：**
- [x] 品种百科 (species.vue)
- [x] 食物百科 (foods.vue)
- [x] 症状百科 (symptoms.vue)
- [ ] AI咨询 (ai.vue)

**后端Controller：** EncyclopediaController.java

**需要的API：**
- [ ] GET /encyclopedia/species - 获取品种列表
- [ ] POST /encyclopedia/species - 创建品种
- [ ] PUT /encyclopedia/species/{id} - 更新品种
- [ ] DELETE /encyclopedia/species/{id} - 删除品种
- [ ] GET /encyclopedia/foods - 获取食物列表
- [ ] POST /encyclopedia/foods - 创建食物
- [ ] PUT /encyclopedia/foods/{id} - 更新食物
- [ ] DELETE /encyclopedia/foods/{id} - 删除食物
- [ ] 症状也需要同样的CRUD

---

### 5. 财务管理 (Finance Management)
**前端页面：**
- [ ] 收入统计
- [ ] 支出管理
- [ ] VIP订单

**后端Controller：** FinanceController.java

**需要的API：**
- [ ] GET /finance/income - 收入统计
- [ ] GET /finance/expenses - 支出列表
- [ ] GET /finance/vip-orders - VIP订单

---

### 6. 开屏管理 (Splash Management)
**前端页面：**
- [x] 订单管理 (orders.vue)
- [x] 名额管理 (quota.vue)
- [x] 审核管理 (review.vue)
- [x] 展示位管理 (slots.vue)
- [x] 日历视图 (calendar.vue)

**后端Controller：** SplashController.java

**需要的API：**
- [ ] GET /splash/orders - 获取订单列表
- [ ] GET /splash/quota - 获取名额配置
- [ ] PUT /splash/quota - 更新名额
- [ ] GET /splash/pending-review - 待审核列表
- [ ] POST /splash/{id}/approve - 审核通过
- [ ] POST /splash/{id}/reject - 审核拒绝

---

### 7. 数据统计 (Statistics)
**前端页面：**
- [x] 仪表板 (dashboard.vue)
- [x] 用户统计 (users.vue)
- [x] 内容统计 (content.vue)
- [x] 业务统计 (business.vue)

**后端Controller：** StatsController.java

**需要的API：**
- [ ] GET /stats/overview - 总览数据
- [ ] GET /stats/users - 用户统计
- [ ] GET /stats/content - 内容统计
- [ ] GET /stats/business - 业务统计
- [ ] GET /stats/trends - 趋势数据

---

### 8. 系统管理 (System Management)
**前端页面：**
- [ ] 管理员管理
- [ ] 系统设置
- [ ] 操作日志

**后端Controller：** SystemController.java

**需要的API：**
- [ ] GET /system/admins - 管理员列表
- [ ] POST /system/admins - 创建管理员
- [ ] GET /system/logs - 操作日志

---

## 下一步行动

1. **完善User模块**
   - 实现所有CRUD API
   - 确保VIP赠送功能正常
   - 实现情侣解绑功能

2. **完善Encyclopedia模块**
   - 实现完整的CRUD
   - 添加数据验证
   - 支持批量导入

3. **完善Splash模块**
   - 实现审核流程
   - 完善名额管理
   - 添加日历展示

4. **完善Statistics模块**
   - 添加实时数据
   - 完善图表展示
   - 支持数据导出

5. **测试所有功能**
   - 前后端联调
   - 数据验证
   - 权限检查
