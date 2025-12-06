# 🦜 鸟之王国 (Bird Kingdom)

一款专为鸟类爱好者打造的综合养护管理平台。

## 📱 应用简介

鸟之王国是集健康管理、社交分享、知识学习于一体的鸟类宠物养护应用。

### 核心功能

- 🏥 **健康档案**：记录鸟儿的基本信息、健康数据、成长历程
- ⏰ **智能提醒**：喂食、换水、清洁等养护事项定时提醒
- 💬 **社交广场**：分享养鸟心得，结识鸟友，交流经验
- 🔍 **寻鸟启事**：发布走失信息，帮助找回爱鸟
- 👑 **VIP服务**：共享管理、数据恢复等高级功能

## 🛠️ 技术栈

### 前端 (iOS)
- SwiftUI
- Combine
- CoreLocation
- PhotosUI

### 后端
- Spring Boot 3.2.0
- MySQL 8.0
- JPA / Hibernate
- JWT 认证
- 网易云信短信服务

## 📦 项目结构

```
bird_kingdom/
├── frontend/           # iOS 前端
│   └── BirdKingdom/
│       ├── Models/     # 数据模型
│       ├── Views/      # 视图组件
│       ├── Services/   # 服务层
│       └── Assets/     # 资源文件
│
├── backend/            # Spring Boot 后端
│   └── src/
│       ├── main/
│       │   ├── java/
│       │   │   └── com/birdkingdom/
│       │   │       ├── controller/  # 控制器
│       │   │       ├── service/     # 服务层
│       │   │       ├── entity/      # 实体类
│       │   │       ├── repository/  # 数据访问层
│       │   │       └── dto/         # 数据传输对象
│       │   └── resources/
│       │       ├── application.yml  # 配置文件
│       │       └── db/migration/    # 数据库迁移
│       └── test/
│
└── docs/               # 文档
```

## 🚀 快速开始

### 前置要求

- Xcode 15.0+
- Java 17+
- Maven 3.8+
- MySQL 8.0+

### 后端启动

```bash
cd backend
mvn clean install
mvn spring-boot:run
```

### 前端启动

1. 打开 `frontend/BirdKingdom/BirdKingdom.xcodeproj`
2. 选择模拟器或真机
3. 点击运行

## ⚙️ 配置说明

### 数据库配置

修改 `backend/src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/bird_kingdom
    username: your_username
    password: your_password
```

### 短信服务配置

```yaml
netease:
  sms:
    app-key: your_app_key
    app-secret: your_app_secret
    template-id: your_template_id
```

## 📱 应用截图

（待添加）

## 🎯 开发路线图

- [x] 用户认证系统
- [x] 鸟类档案管理
- [x] 健康日志记录
- [x] 社交广场功能
- [x] VIP会员系统
- [x] 寻鸟启事功能
- [ ] 专家咨询系统
- [ ] 知识库完善
- [ ] 数据统计分析
- [ ] 多语言支持

## 📄 许可证

本项目为私有项目，未经授权不得使用。

## 👨‍💻 作者

ibomb017

## 📞 联系方式

如有问题或建议，请联系开发者。

---

**鸟之王国** - 让养鸟生活更科学、更有趣 🦜
