# 🦜 鸟鸟王国 (Bird Kingdom)

> 一款专为鸟类爱好者打造的综合养护管理平台

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org/)
[![Vapor](https://img.shields.io/badge/Vapor-4.x-purple.svg)](https://vapor.codes/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-blue.svg)](https://www.mysql.com/)

---

## 📱 应用简介

**鸟鸟王国**是集健康管理、社交分享、知识学习于一体的鸟类宠物养护应用。帮助养鸟者更科学地照料鸟类，记录成长过程，建立自己的"鸟类档案王国"。

### ✨ 核心特色

| 模块 | 功能 | 说明 |
|------|------|------|
| 🏠 **鸟舍管理** | 档案记录 | 完整的鸟儿信息档案管理 |
| 📝 **健康日志** | 成长记录 | 每日喂养、体重、行为记录 |
| 📊 **数据分析** | 趋势图表 | 体重曲线、生理周期预测 |
| ⏰ **智能提醒** | 定时任务 | 喂食、清洁、称重提醒 |
| 💬 **社交广场** | 分享交流 | 发布动态，结识鸟友 |
| 🔍 **寻鸟启事** | 走失帮助 | 发布寻鸟信息，地图定位 |
| 📚 **品种百科** | 知识库 | 品种、食物安全、症状查询 |
| 🤖 **AI问诊** | 智能助手 | 基于AI的健康咨询 |
| 👑 **VIP服务** | 高级功能 | 共养、AI问诊、数据恢复 |
| 🎉 **开屏庆生** | 专属展示 | 购买开屏位展示爱鸟 |

---

## 📦 项目结构

```
bird_kingdom/
│
├── 📱 frontend/                        # iOS 前端应用 (SwiftUI)
│   └── BirdKingdom/
│       ├── BirdKingdom.xcodeproj/      # Xcode 项目配置
│       └── BirdKingdom/                # 源代码目录
│           ├── Assets.xcassets/        # 图片资源
│           ├── Data/                   # 静态数据文件
│           ├── Extensions/             # Swift 扩展
│           ├── Models/                 # 数据模型
│           ├── Services/               # 服务层 (API/本地存储)
│           │   ├── ApiService.swift    # 网络请求服务
│           │   ├── AppConfig.swift     # 环境配置（重要！）
│           │   ├── AuthService.swift   # 认证服务
│           │   └── ...
│           ├── Views/                  # SwiftUI 视图
│           │   ├── Home/               # 首页 - 鸟舍管理
│           │   ├── Encyclopedia/       # 百科 - 知识中心
│           │   ├── Forum/              # 广场 - 社交论坛
│           │   └── Profile/            # 我的 - 个人中心
│           └── BirdKingdomApp.swift    # App 入口
│
├── 🖥️ backend-swift/                   # Swift Vapor 后端服务 ⭐ 当前使用
│   ├── Sources/App/
│   │   ├── configure.swift             # 应用配置（含日期格式）
│   │   ├── routes.swift                # 路由配置
│   │   ├── Controllers/                # API 控制器
│   │   │   ├── AuthController.swift    # 认证接口
│   │   │   ├── BirdController.swift    # 鸟档案接口
│   │   │   ├── ForumController.swift   # 论坛接口
│   │   │   ├── UserController.swift    # 用户接口
│   │   │   └── ...
│   │   ├── Models/                     # Fluent ORM 模型
│   │   ├── DTOs/                       # 数据传输对象
│   │   └── Middleware/                 # 中间件
│   ├── Dockerfile                      # Docker 镜像配置
│   ├── Package.swift                   # Swift 包配置
│   ├── .env.example                    # 环境变量示例
│   └── README.md                       # 后端说明文档
│
├── 🌐 admin-web/                       # 管理端 Web 应用 (React)
│   ├── frontend/                       # React 前端
│   └── backend/                        # Node.js 后端
│
├── 📄 docs/                            # 项目文档
│   ├── ADMIN_SYSTEM_PROMPT.md          # 管理端系统设计
│   ├── 鸟鸟王国APP完整功能需求文档.md    # 完整需求文档
│   └── privacy.html                    # 隐私政策
│
├── .gitignore                          # Git 忽略规则
└── README.md                           # 项目说明 (本文档)
```

---

## 🛠️ 技术栈

### 前端 (iOS)
| 技术 | 用途 |
|------|------|
| SwiftUI | UI框架 |
| Combine | 响应式编程 |
| URLSession | 网络请求 |
| StoreKit 2 | Apple 内购 (IAP) |
| AVFoundation | 视频播放/录制 |
| Swift Charts | 数据图表 |

### 后端 (Swift Vapor) ⭐ 当前使用
| 技术 | 用途 |
|------|------|
| Vapor 4.x | Web 框架 |
| Fluent | ORM |
| FluentMySQLDriver | MySQL 驱动 |
| JWT | 身份认证 |
| Docker | 容器化部署 |

### 云服务
| 服务 | 用途 |
|------|------|
| 阿里云 ECS | 服务器托管 |
| 阿里云 OSS | 文件存储 |
| 阿里云短信 | 验证码发送 |
| MySQL 8.0 | 数据库 |

---

## 🚀 快速开始

### 环境要求

| 工具 | 版本要求 |
|------|---------| 
| Xcode | 15.0+ |
| iOS 设备/模拟器 | iOS 15.0+ |
| Swift | 5.10+ |
| Docker | 20.0+ |
| MySQL | 8.0+ |

---

## 💻 本地开发

### 前端启动

1. 打开 `frontend/BirdKingdom/BirdKingdom.xcodeproj`

2. **配置后端地址** (重要！)
   
   编辑 `Services/AppConfig.swift`:
   ```swift
   // 本地开发 - 连接本地后端
   static let currentEnvironment: Environment = .development
   
   // 测试生产环境
   static let currentEnvironment: Environment = .production
   ```

3. 选择模拟器或真机设备，点击运行 (⌘R)

### 后端本地启动

#### 方式一：直接运行 (需要本地 Swift 环境)

```bash
cd backend-swift

# 配置环境变量
cp .env.example .env
# 编辑 .env 填入数据库配置

# 运行
swift run
```

#### 方式二：Docker 运行 (推荐)

```bash
cd backend-swift

# 构建镜像
docker build -t swift-backend-backend:latest .

# 运行容器
docker run -d \
  --name birdkingdom-swift \
  --network host \
  -e DB_HOST=127.0.0.1 \
  -e DB_PORT=3306 \
  -e DB_USERNAME=root \
  -e DB_PASSWORD=your_password \
  -e DB_NAME=bird_kingdom \
  -e JWT_SECRET=your-jwt-secret \
  swift-backend-backend:latest
```

#### 通过 SSH 隧道连接远程数据库

```bash
# 创建 SSH 隧道 (本地 3307 -> 服务器 3306)
ssh -f -N -L 3307:127.0.0.1:3306 root@47.84.177.155

# 然后在 .env 中配置
# DB_HOST=127.0.0.1
# DB_PORT=3307
```

---

## 🌐 服务器部署

### 生产服务器信息

| 项目 | 信息 |
|------|------|
| **服务器** | 阿里云 ECS |
| **IP** | 47.84.177.155 |
| **域名** | birdkingdom.xyz |
| **SSH 用户** | root |
| **SSH 密码** | Chen_20040601 |

### ⚠️ 服务器目录结构 (重要！上传前必读)

```
/www/                                    # Web 服务根目录
├── wwwroot/                             # 网站根目录
│   └── birdkingdom/                     # Bird Kingdom 项目目录
│       ├── swift-backend/               # ⭐ Swift 后端部署目录 (重要！)
│       │   ├── App                      # 当前运行的可执行文件
│       │   ├── App-new                  # 新版本待部署文件（上传到这里）
│       │   ├── App-backup-YYYYMMDD      # 备份文件
│       │   ├── .env                     # 环境配置文件
│       │   ├── logs/                    # 日志目录
│       │   │   └── app.log              # 应用日志
│       │   ├── Sources/                 # 源代码（可选，用于查看）
│       │   ├── Package.swift            # Swift 包配置
│       │   └── README.md                # 后端说明
│       │
│       ├── privacy.html                 # 隐私政策页面
│       └── logs/                        # 其他日志
│
├── server/                              # 服务器管理面板（BT宝塔等）
└── backup/                              # 备份目录

/root/                                   # ⚠️ 不要在此创建项目目录！
└── (临时文件、系统配置等)
```

**🔴 部署规则：**
1. **Swift 后端**必须部署到：`/www/wwwroot/birdkingdom/swift-backend/`
2. 新文件先上传为 `App-new`，测试无误后再重命名为 `App`
3. **绝对不要**在 `/root/` 目录下创建项目文件

### 部署 Swift 后端

#### 1. SSH 连接到服务器

```bash
ssh root@47.84.177.155
# 密码: Chen_20040601
```

#### 2. 查看当前运行状态

```bash
# 查看 Swift 后端容器
docker ps | grep birdkingdom-swift

# 查看日志
docker logs birdkingdom-swift --tail 50
```

### 部署 Swift 后端

#### 方式一：直接部署可执行文件（推荐）⭐

**步骤1：本地编译**
```bash
cd backend-swift
swift build -c release

# 编译产物位置：
# .build/arm64-apple-macosx/release/BirdKingdomServer
```

**步骤2：上传到服务器**
```bash
# ⚠️ 注意：必须上传到 /www/wwwroot/birdkingdom/swift-backend/
sshpass -p "Chen_20040601" scp \
  backend-swift/.build/arm64-apple-macosx/release/BirdKingdomServer \
  root@47.84.177.155:/www/wwwroot/birdkingdom/swift-backend/App-new
```

**步骤3：SSH 登录部署**
```bash
ssh root@47.84.177.155
# 密码: Chen_20040601

# 切换到正确目录
cd /www/wwwroot/birdkingdom/swift-backend

# 停止旧服务
pkill -f 'swift-backend/App' || true
sleep 2

# 备份旧版本
if [ -f App ]; then 
  mv App App-backup-$(date +%Y%m%d-%H%M%S)
fi

# 使用新版本
mv App-new App
chmod +x App

# 启动服务
nohup ./App serve --env production --hostname 0.0.0.0 --port 8080 > logs/app.log 2>&1 &

# 等待启动
sleep 3

# 检查服务
ps aux | grep 'swift-backend/App' | grep -v grep

# 查看日志
tail -50 logs/app.log
```

**步骤4：验证部署**
```bash
# 健康检查
curl http://47.84.177.155:8080/
# 预期返回：200 OK

# 测试 API
curl http://47.84.177.155:8080/api/v1/notifications/unread-count \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 方式二：Docker 部署（暂未使用）

> **注意**：当前生产环境使用方式一（直接部署），以下仅作参考

```bash
# 构建镜像
cd backend-swift
docker build -t swift-backend:latest .

# 运行容器
docker run -d \
  --name birdkingdom-swift \
  --network host \
  -e DB_HOST=127.0.0.1 \
  -e DB_PORT=3306 \
  -e DB_USERNAME=root \
  -e DB_PASSWORD=Chen_20040601 \
  -e DB_NAME=bird_kingdom \
  -e JWT_SECRET=your-jwt-secret \
  swift-backend:latest
```

### 管理端 Web (端口 8081)

```bash
# 管理端后端使用 Java
# 端口: 8081
# 查看运行状态
ps aux | grep admin-backend
```

---

## ⚙️ 配置说明

### 前端环境配置 (`AppConfig.swift`)

```swift
// 切换环境
static let currentEnvironment: Environment = .production  // 生产环境
// static let currentEnvironment: Environment = .development  // 开发环境

// 本地 IP (真机调试用)
private static let localNetworkIP = "192.168.0.28"

// 生产服务器
private static let productionServer = "birdkingdom.xyz"
```

### 后端环境变量 (`.env`)

```bash
# 服务器配置
HOST=0.0.0.0
PORT=8080

# 数据库配置
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=your_password
DB_NAME=bird_kingdom
DB_USE_SSL=false

# JWT 配置
JWT_SECRET=your-super-secret-jwt-key

# 开发模式 (允许万能验证码 123456)
APP_DEV_MODE=true  # 生产环境设为 false
```

---

## 📊 API 接口概览

### 主要端点

| 控制器 | 路径 | 功能 |
|--------|------|------|
| AuthController | `/api/auth` | 登录/注册/验证码 |
| BirdController | `/api/birds` | 鸟档案 CRUD |
| ForumController | `/api/forum` | 帖子/评论/点赞 |
| UserController | `/api/users` | 用户/关注/粉丝 |
| UploadController | `/api/upload` | 文件上传 |
| ReportBlockController | `/api/*/report` | 举报/拉黑 |

### 健康检查

```bash
# 检查服务状态
curl https://birdkingdom.xyz/health  # 生产环境
curl http://localhost:8080/health    # 本地

# 检查 API 版本
curl https://birdkingdom.xyz/api
```

---

## 🔧 常见问题排查

### 问题1: 鸟舍数据无法加载

**可能原因**: 
- 日期格式不匹配（已修复：使用 ISO 8601 格式）
- Token 无效或过期

**解决方案**:
```bash
# 检查后端日志
docker logs birdkingdom-swift --tail 100

# 查看是否有解码错误
docker logs birdkingdom-swift 2>&1 | grep -i error
```

### 问题2: 登录失败

**检查**:
1. JWT_SECRET 是否与之前一致
2. APP_DEV_MODE 是否开启（允许万能验证码）

### 问题3: 前端连不上后端

**检查 `AppConfig.swift`**:
1. `currentEnvironment` 是否正确
2. 本地开发时 `localNetworkIP` 是否正确
3. 手机和电脑是否在同一 WiFi

---

## 📄 重要文件说明

| 文件 | 说明 |
|------|------|
| `frontend/.../AppConfig.swift` | 前端环境配置（**开发必看**） |
| `backend-swift/Sources/App/configure.swift` | 后端核心配置（日期格式、数据库） |
| `backend-swift/.env` | 后端环境变量（敏感信息，不提交） |
| `backend-swift/Dockerfile` | Docker 镜像配置 |

---

## 📞 联系方式

- **官网**: https://birdkingdom.xyz
- **邮箱**: birdkingdom@163.com
- **反馈**: 应用内「设置 → 意见反馈」

---

## 📜 许可证

本项目为私有项目，未经授权不得使用、复制或分发。

Copyright © 2024 Bird Kingdom. All rights reserved.

---

<p align="center">
  <b>🦜 鸟鸟王国 - 让养鸟生活更科学、更有趣</b>
</p>
