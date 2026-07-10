# Bird Kingdom Swift Backend
# 使用官方 Swift 镜像作为构建环境
FROM swift:5.9-jammy as builder

# 设置工作目录
WORKDIR /app

# 复制 Package 文件并解析依赖
COPY Package.swift Package.resolved ./
RUN swift package resolve

# 复制源代码
COPY Sources ./Sources
COPY Tests ./Tests

# 构建 Release 版本
RUN swift build -c release --static-swift-stdlib

# 运行环境使用更小的 Ubuntu 镜像
FROM ubuntu:22.04

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# 设置时区为中国时间
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建非 root 用户
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app

# 从构建阶段复制编译好的二进制文件
COPY --from=builder --chown=vapor:vapor /app/.build/release/BirdKingdomServer ./
COPY --chown=vapor:vapor docs ./docs

# 切换到非 root 用户
USER vapor:vapor

# 暴露端口
EXPOSE 8080

# 启动服务
ENTRYPOINT ["./BirdKingdomServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
