# Bird Kingdom Swift Backend

基于 Vapor 框架的 Swift 后端服务，与 Java Spring Boot 后端功能等效。

## 技术栈

- **Swift 5.9+**
- **Vapor 4.x** - Swift 后端框架
- **Fluent** - ORM 框架
- **FluentMySQLDriver** - MySQL 数据库驱动
- **JWT** - JSON Web Token 认证

## 项目结构

```
backend-swift/
├── Package.swift          # Swift 包配置
├── Sources/
│   └── App/
│       ├── configure.swift    # 应用配置
│       ├── routes.swift       # 路由配置
│       ├── entrypoint.swift   # 入口文件
│       ├── Controllers/       # 控制器
│       ├── Models/            # 数据模型
│       ├── DTOs/              # 数据传输对象
│       ├── Services/          # 业务服务
│       ├── Middleware/        # 中间件
│       └── Migrations/        # 数据库迁移
└── Tests/                 # 测试
```

## 开发环境设置

### 1. 安装依赖

确保已安装 Swift 5.9+ 和 macOS 13+

```bash
# 检查 Swift 版本
swift --version
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，填入数据库和其他配置
```

### 3. 运行项目

```bash
# 开发模式运行
swift run

# 或者使用 Xcode
open Package.swift
```

### 4. 编译发布版本

```bash
swift build -c release
```

## API 端点

与 Java 后端保持一致的 API 端点：

### 认证
- `POST /api/auth/send-code` - 发送验证码
- `POST /api/auth/login` - 验证码登录
- `POST /api/auth/login-password` - 密码登录
- `GET /api/auth/me` - 获取当前用户
- `PUT /api/auth/profile` - 更新用户信息

### 用户
- `GET /api/users/:userId` - 获取用户信息
- `GET /api/users/:userId/full-stats` - 获取用户完整统计
- `POST /api/users/:userId/follow` - 关注/取消关注
- `GET /api/users/:userId/following` - 获取关注列表
- `GET /api/users/:userId/followers` - 获取粉丝列表

### 论坛
- `GET /api/forum/posts` - 获取帖子列表
- `GET /api/forum/posts/:postId` - 获取帖子详情
- `POST /api/forum/posts` - 发布帖子
- `DELETE /api/forum/posts/:postId` - 删除帖子
- `POST /api/forum/posts/:postId/like` - 点赞/取消点赞
- `POST /api/forum/posts/:postId/favorite` - 收藏/取消收藏
- `GET /api/forum/posts/:postId/comments` - 获取评论
- `POST /api/forum/posts/:postId/comments` - 发表评论

### 鸟儿
- `GET /api/birds` - 获取我的鸟儿列表
- `POST /api/birds` - 添加鸟儿
- `PUT /api/birds/:birdId` - 更新鸟儿
- `DELETE /api/birds/:birdId` - 删除鸟儿

### 举报和拉黑
- `POST /api/forum/posts/:postId/report` - 举报帖子
- `POST /api/users/:userId/block` - 拉黑用户
- `GET /api/users/blocked` - 获取拉黑列表

## 部署

### Linux 服务器部署

1. 安装 Swift：
```bash
# Ubuntu/Debian
apt-get install swift
```

2. 编译：
```bash
swift build -c release
```

3. 运行：
```bash
.build/release/BirdKingdomServer
```

### Docker 部署

```bash
docker build -t bird-kingdom-swift .
docker run -p 8080:8080 bird-kingdom-swift
```

## 与 Java 后端的主要差异

1. **语法差异**：Swift 使用更现代的语法
2. **类型系统**：Swift 是强类型语言，编译时检查更严格
3. **异步处理**：使用 Swift 的 async/await
4. **性能**：编译型语言，性能通常更好

## 迁移进度

### 已完成
- [x] 项目结构和配置
- [x] 数据库模型（User, Bird, ForumPost, PostComment, PostLike, PostFavorite, PostReport, UserFollow, UserBlock, VerificationCode）
- [x] 认证控制器（登录、注册、密码管理）
- [x] 用户控制器（信息、关注、粉丝）
- [x] 论坛控制器（帖子、评论、点赞、收藏）
- [x] 鸟儿控制器（CRUD、状态管理）
- [x] 举报拉黑控制器
- [x] 上传控制器（需集成 OSS）

### 待完成
- [ ] 阿里云 OSS 集成
- [ ] 阿里云短信集成
- [ ] VIP 功能
- [ ] 情侣账号功能
- [ ] 通知系统
- [ ] 百科模块
- [ ] 开屏广告模块
- [ ] AI 功能
