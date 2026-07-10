package com.birdkingdom.smsproxy.service;

import com.aliyun.dysmsapi20170525.Client;
import com.aliyun.dysmsapi20170525.models.SendSmsRequest;
import com.aliyun.dysmsapi20170525.models.SendSmsResponse;
import com.aliyun.teaopenapi.models.Config;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class AliyunSmsService {

    @Value("${aliyun.sms.access-key-id}")
    private String accessKeyId;

    @Value("${aliyun.sms.access-key-secret}")
    private String accessKeySecret;

    @Value("${aliyun.sms.sign-name}")
    private String signName;

    @Value("${aliyun.sms.template-code}")
    private String templateCode;

    @Value("${aliyun.sms.region-id:cn-hangzhou}")
    private String regionId;

    /**
     * 发送短信验证码
     * 
     * @param phone 手机号
     * @param code  验证码
     * @return 发送结果
     */
    public SmsResult sendVerificationCode(String phone, String code) {
        try {
            // 检查配置
            if (accessKeyId == null || accessKeyId.isEmpty() ||
                    accessKeySecret == null || accessKeySecret.isEmpty()) {
                System.err.println("❌ 阿里云SMS配置缺失");
                return SmsResult.failure("SMS配置缺失");
            }

            // 创建客户端配置
            Config config = new Config()
                    .setAccessKeyId(accessKeyId)
                    .setAccessKeySecret(accessKeySecret)
                    .setRegionId(regionId)
                    .setEndpoint("dysmsapi.aliyuncs.com");

            Client client = new Client(config);

            // 构建请求
            SendSmsRequest sendSmsRequest = new SendSmsRequest()
                    .setPhoneNumbers(phone)
                    .setSignName(signName)
                    .setTemplateCode(templateCode)
                    .setTemplateParam("{\"code\":\"" + code + "\"}");

            // 发送短信
            SendSmsResponse response = client.sendSms(sendSmsRequest);

            String respCode = response.getBody().getCode();
            String respMessage = response.getBody().getMessage();

            System.out.println("📨 阿里云SMS响应: " + respCode + " - " + respMessage);

            if ("OK".equals(respCode)) {
                System.out.println("✅ 短信发送成功: " + phone);
                return SmsResult.success();
            } else {
                System.err.println("❌ 短信发送失败: " + respCode + " - " + respMessage);
                return SmsResult.failure(respMessage);
            }

        } catch (Exception e) {
            System.err.println("❌ 短信发送异常: " + e.getMessage());
            e.printStackTrace();
            return SmsResult.failure("发送异常: " + e.getMessage());
        }
    }

    /**
     * 短信发送结果
     */
    public static class SmsResult {
        private final boolean success;
        private final String message;

        private SmsResult(boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        public static SmsResult success() {
            return new SmsResult(true, "发送成功");
        }

        public static SmsResult failure(String message) {
            return new SmsResult(false, message);
        }

        public boolean isSuccess() {
            return success;
        }

        public String getMessage() {
            return message;
        }
    }
}
