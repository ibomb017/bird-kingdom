# 鸟鸟王国后端服务

基于 Spring Boot 3.2 的后端 API 服务。

## 技术栈

- **Java 17**
- **Spring Boot 3.2.0**
- **Spring Data JPA**
- **H2 Database**（开发环境）
- **MySQL**（生产环境）
- **Lombok**

## 项目结构

```
backend/
├── pom.xml                          # Maven 配置
├── src/main/java/com/birdkingdom/
│   ├── BirdKingdomApplication.java  # 启动类
│   ├── config/
│   │   └── DataInitializer.java     # 初始化示例数据
│   ├── controller/
│   │   ├── BirdController.java      # 鸟档案接口
│   │   ├── BirdLogController.java   # 日志接口
│   │   └── ReminderController.java  # 提醒接口
│   ├── dto/
│   │   ├── BirdDTO.java
│   │   ├── BirdLogDTO.java
│   │   ├── ReminderDTO.java
│   │   └── WeightTrendDTO.java
│   ├── entity/
│   │   ├── Bird.java                # 鸟档案实体
│   │   ├── BirdLog.java             # 日志实体
│   │   └── Reminder.java            # 提醒实体
│   ├── exception/
│   │   └── GlobalExceptionHandler.java
│   ├── repository/
│   │   ├── BirdRepository.java
│   │   ├── BirdLogRepository.java
│   │   └── ReminderRepository.java
│   └── service/
│       ├── BirdService.java
│       ├── BirdLogService.java
│       └── ReminderService.java
└── src/main/resources/
    └── application.yml              # 配置文件
```

## 快速开始

### 1. 环境要求

- JDK 17+
- Maven 3.8+

### 2. 启动服务（开发模式）

```bash
cd backend
mvn spring-boot:run
```

服务将在 `http://localhost:8080` 启动。

### 3. 访问 H2 控制台（开发环境）

- 地址：http://localhost:8080/h2-console
- JDBC URL：`jdbc:h2:mem:birdkingdom`
- 用户名：`sa`
- 密码：（空）

## API 接口

### 鸟档案 `/api/birds`

| 方法   | 路径          | 说明         |
|--------|---------------|--------------|
| GET    | /api/birds    | 获取所有鸟   |
| GET    | /api/birds/{id} | 获取单只鸟 |
| POST   | /api/birds    | 创建鸟档案   |
| PUT    | /api/birds/{id} | 更新鸟档案 |
| DELETE | /api/birds/{id} | 删除鸟档案 |

### 日志 `/api/logs`

| 方法   | 路径                  | 说明               |
|--------|-----------------------|--------------------|
| GET    | /api/logs             | 获取所有日志       |
| GET    | /api/logs/{id}        | 获取单条日志       |
| GET    | /api/logs/bird/{birdId} | 获取某只鸟的日志 |
| POST   | /api/logs             | 创建日志           |
| PUT    | /api/logs/{id}        | 更新日志           |
| DELETE | /api/logs/{id}        | 删除日志           |
| GET    | /api/logs/weight-trend | 获取体重趋势      |

**体重趋势参数：**
- `birdId`（可选）：鸟ID，不传则返回所有鸟
- `range`：时间范围，可选值 `week`, `month`, `quarter`, `year`

### 提醒 `/api/reminders`

| 方法   | 路径                     | 说明             |
|--------|--------------------------|------------------|
| GET    | /api/reminders           | 获取所有提醒     |
| GET    | /api/reminders/enabled   | 获取已启用的提醒 |
| GET    | /api/reminders/{id}      | 获取单个提醒     |
| POST   | /api/reminders           | 创建提醒         |
| PUT    | /api/reminders/{id}      | 更新提醒         |
| PATCH  | /api/reminders/{id}/toggle | 切换启用状态   |
| DELETE | /api/reminders/{id}      | 删除提醒         |

## 生产环境部署

### 1. 配置 MySQL

修改 `application.yml` 中的生产环境配置：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/bird_kingdom
    username: your_username
    password: your_password
```

### 2. 创建数据库

```sql
CREATE DATABASE bird_kingdom CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 3. 启动生产模式

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=prod
```

或打包后运行：

```bash
mvn clean package
java -jar target/bird-kingdom-backend-1.0.0.jar --spring.profiles.active=prod
```
