# 阿里云短信服务配置指南

## 📋 前置准备

### 1. 注册阿里云账号
访问：https://www.aliyun.com/

### 2. 开通短信服务
1. 登录阿里云控制台
2. 搜索"短信服务"
3. 点击"立即开通"
4. 完成实名认证

---

## 🔑 获取AccessKey

### 步骤：
1. 登录阿里云控制台
2. 鼠标悬停右上角头像
3. 点击"AccessKey管理"
4. 创建AccessKey
5. **重要：立即保存AccessKey ID和AccessKey Secret（只显示一次）**

### 示例：
```
AccessKey ID: LTAI5tXXXXXXXXXXXXXX
AccessKey Secret: 3vXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 📝 配置短信签名

### 什么是短信签名？
短信签名是短信开头的【】内容，例如：【鸟之王国】您的验证码是123456

### 步骤：
1. 进入短信服务控制台
2. 点击"国内消息" -> "签名管理"
3. 点击"添加签名"
4. 填写信息：
   - 签名名称：鸟之王国
   - 签名来源：企业全称/网站/APP等
   - 上传相关证明材料
5. 提交审核（通常1-2个工作日）

---

## 📄 配置短信模板

### 什么是短信模板？
短信模板是短信的正文内容，包含变量占位符

### 步骤：
1. 进入短信服务控制台
2. 点击"国内消息" -> "模板管理"
3. 点击"添加模板"
4. 填写信息：
   - 模板类型：验证码
   - 模板名称：登录验证码
   - 模板内容：您的验证码是${code}，5分钟内有效，请勿泄露给他人。
5. 提交审核（通常1-2个工作日）

### 审核通过后会得到：
```
模板CODE: SMS_123456789
```

---

## ⚙️ 配置application.yml

### 修改配置文件：
```yaml
# 阿里云短信配置
aliyun:
  sms:
    access-key-id: LTAI5tXXXXXXXXXXXXXX          # 你的AccessKey ID
    access-key-secret: 3vXXXXXXXXXXXXXXXXXXXXXX  # 你的AccessKey Secret
    sign-name: 鸟之王国                           # 你的短信签名
    template-code: SMS_123456789                 # 你的模板CODE
    region-id: cn-hangzhou                       # 区域ID（默认杭州）
```

### ⚠️ 安全提示：
1. **不要将AccessKey提交到Git仓库**
2. 建议使用环境变量：
```yaml
aliyun:
  sms:
    access-key-id: ${ALIYUN_ACCESS_KEY_ID}
    access-key-secret: ${ALIYUN_ACCESS_KEY_SECRET}
```

3. 在服务器上设置环境变量：
```bash
export ALIYUN_ACCESS_KEY_ID=your_key_id
export ALIYUN_ACCESS_KEY_SECRET=your_key_secret
```

---

## 🧪 测试短信发送

### 1. 启动后端服务
```bash
cd backend
mvn spring-boot:run
```

### 2. 测试发送验证码
```bash
curl -X POST http://localhost:8080/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000"}'
```

### 3. 检查结果

**成功：**
```
✅ 短信发送成功: 13800138000 - 123456
📱 验证码 [13800138000]: 123456
```

**失败：**
```
❌ 短信发送失败: InvalidAccessKeyId.NotFound
⚠️ 短信发送失败，验证码 [13800138000]: 123456
```

---

## 💰 费用说明

### 短信费用：
- 验证码短信：约 **0.045元/条**
- 通知短信：约 **0.045元/条**
- 营销短信：约 **0.055元/条**

### 充值方式：
1. 进入短信服务控制台
2. 点击"充值"
3. 选择充值金额（建议先充值100元测试）

### 费用优化：
1. 开发环境使用控制台打印（已实现）
2. 添加发送频率限制（防止恶意刷验证码）
3. 验证码有效期设置为5分钟

---

## 🔒 安全最佳实践

### 1. AccessKey安全
```java
// ❌ 不要硬编码
String accessKeyId = "LTAI5tXXXXXXXXXXXXXX";

// ✅ 使用配置文件
@Value("${aliyun.sms.access-key-id}")
private String accessKeyId;
```

### 2. 频率限制
```java
// 建议添加：同一手机号60秒内只能发送一次
@Cacheable(value = "sms-limit", key = "#phone")
public boolean checkSmsLimit(String phone) {
    return true;
}
```

### 3. IP限制
```java
// 建议添加：同一IP每天最多发送10次
@Cacheable(value = "ip-limit", key = "#ip")
public int getSmsCountByIp(String ip) {
    return 0;
}
```

---

## 📱 短信模板示例

### 1. 登录验证码
```
您的验证码是${code}，5分钟内有效，请勿泄露给他人。
```

### 2. 修改手机号验证
```
您正在修改手机号，验证码${code}，5分钟内有效。如非本人操作，请忽略。
```

### 3. 找回密码
```
您正在找回密码，验证码${code}，5分钟内有效。如非本人操作，请忽略。
```

### 4. 寻鸟通知
```
您发布的寻鸟启事【${birdName}】有新的线索，请及时查看。
```

---

## 🐛 常见问题

### 1. InvalidAccessKeyId.NotFound
**原因：** AccessKey ID错误或不存在  
**解决：** 检查AccessKey ID是否正确

### 2. SignatureDoesNotMatch
**原因：** AccessKey Secret错误  
**解决：** 检查AccessKey Secret是否正确

### 3. isv.BUSINESS_LIMIT_CONTROL
**原因：** 短信发送频率超限  
**解决：** 等待60秒后重试

### 4. isv.TEMPLATE_MISSING_PARAMETERS
**原因：** 模板参数缺失  
**解决：** 检查模板参数是否完整

### 5. isv.INVALID_PARAMETERS
**原因：** 手机号格式错误  
**解决：** 检查手机号是否为11位数字

---

## 📊 监控与日志

### 查看发送记录：
1. 进入短信服务控制台
2. 点击"国内消息" -> "发送记录"
3. 可以查看：
   - 发送时间
   - 手机号
   - 发送状态
   - 失败原因

### 后端日志：
```
✅ 短信发送成功: 13800138000 - 123456
📱 验证码 [13800138000]: 123456
```

---

## ✅ 配置检查清单

- [ ] 已注册阿里云账号
- [ ] 已开通短信服务
- [ ] 已完成实名认证
- [ ] 已创建AccessKey
- [ ] 已配置短信签名（审核通过）
- [ ] 已配置短信模板（审核通过）
- [ ] 已修改application.yml配置
- [ ] 已充值短信费用
- [ ] 已测试短信发送
- [ ] AccessKey未提交到Git

---

## 🚀 下一步

配置完成后：
1. 重启后端服务
2. 在前端测试发送验证码
3. 检查手机是否收到短信
4. 验证码是否可以正常登录

**开发环境：** 即使短信发送失败，控制台也会打印验证码，可以继续测试  
**生产环境：** 必须确保短信发送成功，否则用户无法登录

---

## 📞 技术支持

- 阿里云短信服务文档：https://help.aliyun.com/product/44282.html
- 阿里云工单系统：https://selfservice.console.aliyun.com/ticket
- 短信服务SDK文档：https://next.api.aliyun.com/api/Dysmsapi/2017-05-25

配置完成！🎉
