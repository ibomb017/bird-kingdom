# 🦜 Bird Kingdom Admin - 企业级测试指南

> 版本: 1.0.0 | 更新日期: 2025-12-26

---

## 📋 环境准备

### 1. 数据库配置

确保 MySQL 数据库 `bird_kingdom` 可访问：

```bash
# 方式一：设置环境变量
export DB_HOST=localhost
export DB_PORT=3306
export DB_NAME=bird_kingdom
export DB_USER=root
export DB_PASSWORD=your_password

# 方式二：创建 .env 文件 (admin-web/backend/.env)
DB_HOST=localhost
DB_PORT=3306
DB_NAME=bird_kingdom
DB_USER=root
DB_PASSWORD=your_password
```

### 2. 系统要求

- **Node.js**: 18+ (推荐 20.x)
- **Java**: 17+
- **Maven**: 3.9+
- **MySQL**: 8.0+

---

## 🚀 快速启动

### 一键启动脚本

```bash
cd /Users/ibomb017/Desktop/bird_kingdom/admin-web
./start-admin.sh
```

### 手动启动

#### 启动后端 (端口 8081)
```bash
cd admin-web/backend
mvn clean package -DskipTests
java -jar target/admin-backend-1.0.0.jar
```

#### 启动前端 (端口 3000)
```bash
cd admin-web
npm run dev
```

---

## 🔑 登录凭证

| 用户名 | 密码 | 角色 |
|--------|------|------|
| `admin` | `123456` | 超级管理员 |

> 注：首次启动后端会自动创建默认管理员账号

---

## ✅ 功能测试检查表

### 1. 认证模块
- [ ] 登录页面正常显示
- [ ] 输入正确凭证可登录
- [ ] 输入错误凭证提示失败
- [ ] 登录后跳转工作台
- [ ] Token 持久化（刷新页面不丢失登录状态）
- [ ] 退出登录功能正常

### 2. 工作台 (Dashboard)
- [ ] 统计卡片显示真实数据（用户数、帖子数等）
- [ ] 用户趋势图表正常渲染
- [ ] 帖子分布饼图正常渲染
- [ ] 收入趋势图表正常渲染
- [ ] 待办事项列表正确显示
- [ ] 数据总览点击可跳转

### 3. 用户管理
- [ ] 用户列表加载正常（分页）
- [ ] 搜索功能正常（手机号/昵称）
- [ ] VIP筛选正常
- [ ] 用户详情弹窗正常
- [ ] 赠送VIP功能正常
- [ ] 批量赠送VIP功能正常
- [ ] 延长VIP功能正常
- [ ] 撤销VIP功能正常
- [ ] 禁用/启用用户功能正常

### 4. 鸟舍管理
- [ ] 鸟档案列表加载正常
- [ ] 搜索/筛选功能正常
- [ ] 鸟详情页正常显示
- [ ] 饲养日志列表正常
- [ ] 回收站功能正常

### 5. 论坛社区
- [ ] 帖子列表加载正常
- [ ] 帖子类型筛选正常
- [ ] 帖子详情正常显示
- [ ] 评论列表正常
- [ ] 举报列表正常
- [ ] 处理举报功能正常

### 6. 品种百科
- [ ] 品种列表正常（分页、搜索）
- [ ] 品种详情正常
- [ ] 食物安全库正常
- [ ] 症状速查正常

### 7. 开屏庆生
- [ ] 待审核列表正常（图片加载）
- [ ] 审核通过功能正常
- [ ] 审核驳回功能正常
- [ ] 展示日历正常

### 8. 数据统计
- [ ] 综合统计页面正常
- [ ] 图表渲染正常

### 9. 系统配置
- [ ] 管理员列表正常
- [ ] 系统配置显示正常
- [ ] 角色权限显示正常

---

## 🔍 API 测试

### 使用 cURL 测试

```bash
# 1. 登录获取 Token
curl -X POST http://localhost:8081/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}'

# 2. 获取仪表盘数据 (替换 YOUR_TOKEN)
curl http://localhost:8081/api/admin/stats/dashboard \
  -H "Authorization: Bearer YOUR_TOKEN"

# 3. 获取用户列表
curl http://localhost:8081/api/admin/users \
  -H "Authorization: Bearer YOUR_TOKEN"

# 4. 获取待审核开屏
curl http://localhost:8081/api/admin/splash/pending-review \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 📊 性能基准

| 指标 | 目标 | 测试方法 |
|------|------|----------|
| 首页加载时间 | < 2s | Chrome DevTools |
| API 响应时间 | < 200ms | Network Tab |
| 列表渲染 (1000条) | < 1s | 分页查询 |
| 图表渲染 | < 500ms | 页面 onMounted |

---

## 🐛 已知问题

1. **操作日志功能**：需要单独实现审计日志表
2. **部分页面占位**：`ai.vue`, `colors.vue`, `parrots.vue` 为占位页面
3. **帖子删除**：当前仅返回提示，需通过主项目实现

---

## 📞 技术支持

如有问题，请检查：
1. 数据库连接是否正常
2. 后端日志 (`admin-web/backend/logs/`)
3. 浏览器控制台错误信息

---

© 2025 Bird Kingdom. All rights reserved.
