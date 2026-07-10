FROM eclipse-temurin:17-jdk-alpine as build

WORKDIR /app

# 复制 Maven 配置
COPY pom.xml .
COPY src src

# 构建应用（使用 Maven Wrapper 或预装 Maven）
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache maven && \
    mvn clean package -DskipTests

# 运行阶段
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 从构建阶段复制 JAR
COPY --from=build /app/target/*.jar app.jar

# 暴露端口
EXPOSE 8081

# 启动命令
ENTRYPOINT ["java", "-jar", "app.jar"]
