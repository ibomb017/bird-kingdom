# 🦜 Bird Kingdom Admin

> 鸟鸟王国管理后台 - 企业级全栈管理系统

## 📋 项目简介

Bird Kingdom Admin 是「鸟鸟王国」APP 的管理后台系统，采用前后端分离架构，提供用户管理、内容审核、数据统计等功能。

## 🏗️ 项目结构

```
admin-web/
├── backend/                          # 后端服务 (Spring Boot)
│   ├── src/main/java/com/birdkingdom/admin/
│   │   ├── AdminApplication.java     # 启动类
│   │   ├── config/                   # 配置类
│   │   │   ├── SecurityConfig.java   # 安全配置
│   │   │   └── JwtUtil.java          # JWT工具
│   │   ├── controller/               # 控制器
│   │   │   ├── AuthController.java   # 认证
│   │   │   ├── StatsController.java  # 统计
│   │   │   ├── UserController.java   # 用户管理
│   │   │   ├── BirdController.java   # 鸟舍管理
│   │   │   ├── ForumController.java  # 论坛管理
│   │   │   ├── SplashController.java # 开屏审核
│   │   │   ├── EncyclopediaController.java
│   │   │   └── SystemController.java # 系统管理
│   │   ├── entity/                   # 实体类
│   │   ├── repository/               # 仓库接口
│   │   └── service/                  # 服务类
│   ├── src/main/resources/
│   │   └── application.yml           # 应用配置
│   └── pom.xml                       # Maven配置
│
├── src/                              # 前端源码 (Vue 3)
│   ├── api/                          # API 接口
│   ├── layout/                       # 布局组件
│   │   ├── index.vue                 # 主布局
│   │   └── components/
│   │       ├── Sidebar.vue           # 左侧导航栏
│   │       └── Header.vue            # 顶部栏
│   ├── router/                       # 路由配置
│   ├── stores/                       # 状态管理
│   ├── styles/                       # 全局样式
│   ├── utils/                        # 工具函数
│   ├── views/                        # 页面组件 (40+页面)
│   │   ├── login/                    # 登录
│   │   ├── dashboard/                # 工作台
│   │   ├── user/                     # 用户管理
│   │   ├── bird/                     # 鸟舍管理
│   │   ├── forum/                    # 论坛社区
│   │   ├── encyclopedia/             # 品种百科
│   │   ├── finance/                  # 财务管理
│   │   ├── splash/                   # 开屏庆生
│   │   ├── statistics/               # 数据统计
│   │   ├── system/                   # 系统配置
│   │   └── error/                    # 错误页面
│   ├── App.vue
│   └── main.ts
│
├── public/                           # 静态资源
├── index.html                        # HTML入口
├── package.json                      # 前端依赖
├── vite.config.ts                    # Vite配置
├── tsconfig.json                     # TS配置
└── README.md                         # 项目说明
```

## 🔑 管理员账号

| 用户名 | 密码 | 角色 |
|--------|------|------|
| `admin` | `123456` | 超级管理员 |

## 🛠️ 技术栈

### 前端
- **框架**: Vue 3.4 + TypeScript 5
- **UI 库**: Element Plus 2.4
- **状态管理**: Pinia
- **路由**: Vue Router 4
- **HTTP**: Axios
- **图表**: ECharts 5
- **构建**: Vite 5
- **样式**: SCSS + CSS Variables

### 后端
- **框架**: Spring Boot 3.2.1
- **安全**: Spring Security + JWT
- **ORM**: Spring Data JPA
- **数据库**: MySQL 8.0
- **构建**: Maven

## 🚀 快速开始

### 前端

```bash
# 进入前端目录
cd admin-web

# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 访问 http://localhost:3000
```

### 后端

```bash
# 进入后端目录
cd admin-web/backend

# 编译打包
mvn clean package -DskipTests

# 运行（需要先配置数据库）
java -jar target/admin-backend-1.0.0.jar
```

### 数据库配置

创建 `.env` 文件或设置环境变量：

```bash
DB_HOST=localhost
DB_PORT=3306
DB_NAME=bird_kingdom
DB_USER=root
DB_PASSWORD=your_password
```

## 📱 功能模块

### 左侧导航栏 (9大模块，45+子功能)

| 模块 | 子功能 |
|------|--------|
| 🏠 工作台 | 核心指标、图表、待办事项 |
| 👤 用户管理 | 用户列表、VIP订单、情侣绑定、用户反馈、用户关系、通知管理 |
| 🐦 鸟舍管理 | 鸟档案、鸟日志、生理周期、提醒管理、共养关系、回收站 |
| 💬 论坛社区 | 帖子管理、评论管理、点赞/收藏、寻鸟帖专项、举报管理 |
| 📚 品种百科 | 品种知识库、食物安全库、症状疾病库、**羽色遗传库**、**鹦鹉品种库**、AI问诊配置 |
| 💰 财务管理 | 支出记录、开屏订单、VIP收入、财务报表 |
| 🎉 开屏庆生 | 展示位管理、图片审核、名额配置、展示日历 |
| 📊 数据统计 | 核心指标、用户分析、内容分析、商业分析 |
| ⚙️ 系统配置 | 角色权限、管理员、系统参数、操作日志、登录日志 |

## 🎨 设计特点

- 🌙 **深色主题** - 默认暗色模式，支持一键切换
- ✨ **现代设计** - 毛玻璃、渐变、微动效
- 📱 **响应式** - 适配各种屏幕尺寸
- 🔐 **权限控制** - 基于 RBAC 的权限系统
- 📊 **数据可视化** - ECharts 图表

## 📝 开发说明

### 前端代理配置

开发模式下，所有 `/api` 请求会被代理到后端服务：

```typescript
// vite.config.ts
proxy: {
  '/api': {
    target: 'http://localhost:8081',
    changeOrigin: true
  }
}
```

### 环境变量

前端 `.env.local`:
```bash
VITE_API_BASE_URL=/api/admin
```

后端 `application.yml`:
```yaml
server:
  port: 8081

spring:
  datasource:
    url: jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}
```

## 📄 API 文档

所有 API 路径前缀: `/api/admin`

| 模块 | 路径 | 说明 |
|------|------|------|
| 认证 | `/auth/login` | 登录 |
| 认证 | `/auth/logout` | 登出 |
| 统计 | `/stats/dashboard` | 仪表盘数据 |
| 统计 | `/stats/user-trend` | 用户趋势 |
| 用户 | `/users` | 用户列表 |
| 用户 | `/users/{id}` | 用户详情 |
| 开屏 | `/splash/pending-review` | 待审核列表 |
| 开屏 | `/splash/{id}/approve` | 审核通过 |
| 开屏 | `/splash/{id}/reject` | 审核驳回 |
| 论坛 | `/forum/posts` | 帖子列表 |
| 论坛 | `/forum/reports` | 举报列表 |
| 鸟舍 | `/birds` | 鸟档案列表 |
| 百科 | `/encyclopedia/species` | 品种列表 |
| 系统 | `/system/admins` | 管理员列表 |
| 系统 | `/system/logs` | 操作日志 |

## 🔐 安全规范

- JWT Token 有效期 24 小时
- 密码 BCrypt 加密存储
- 手机号脱敏显示
- 操作审计日志

---

© 2025 Bird Kingdom. All rights reserved.
