# SMS Proxy Service / 短信代理服务

国内阿里云服务器部署的短信代理服务，用于转发来自海外服务器的短信发送请求。

## 架构

```
新加坡服务器 --HTTP--> 国内代理服务 --SDK--> 阿里云短信
```

## 快速部署

### 1. 配置环境变量

```bash
cp .env.example .env
vim .env
```

必须配置：
- `SMS_PROXY_API_KEY`: API认证密钥（新加坡服务器调用时需要）
- `ALIYUN_SMS_ACCESS_KEY_ID`: 阿里云 AccessKey ID
- `ALIYUN_SMS_ACCESS_KEY_SECRET`: 阿里云 AccessKey Secret

### 2. Docker 部署

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 3. 验证服务

```bash
# 健康检查
curl http://localhost:8081/internal/sms/health

# 测试发送（需要 API Key）
curl -X POST http://localhost:8081/internal/sms/send \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"phone":"13587877696","code":"123456"}'
```

## API 文档

### 发送短信验证码

**POST** `/internal/sms/send`

**Headers:**
- `Content-Type: application/json`
- `X-API-Key: <your-api-key>`

**Body:**
```json
{
  "phone": "13587877696",
  "code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "发送成功"
}
```

### 健康检查

**GET** `/internal/sms/health`

```json
{
  "status": "UP",
  "service": "sms-proxy"
}
```

## 安全说明

- 所有 `/internal/sms/*` 接口需要 `X-API-Key` 认证
- 建议配置阿里云安全组，仅允许新加坡服务器 IP 访问 8081 端口
