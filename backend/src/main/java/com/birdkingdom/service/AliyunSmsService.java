package com.birdkingdom.service;

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
     * @param phone 手机号
     * @param code 验证码
     * @return 是否发送成功
     */
    public boolean sendVerificationCode(String phone, String code) {
        try {
            // 创建客户端配置
            Config config = new Config()
                    .setAccessKeyId(accessKeyId)
                    .setAccessKeySecret(accessKeySecret)
                    .setRegionId(regionId)
                    .setEndpoint("dysmsapi.aliyuncs.com");

            // 创建客户端
            Client client = new Client(config);

            // 构建请求
            SendSmsRequest sendSmsRequest = new SendSmsRequest()
                    .setPhoneNumbers(phone)
                    .setSignName(signName)
                    .setTemplateCode(templateCode)
                    .setTemplateParam("{\"code\":\"" + code + "\"}");

            // 发送短信
            SendSmsResponse response = client.sendSms(sendSmsRequest);

            // 检查返回结果
            if ("OK".equals(response.getBody().getCode())) {
                System.out.println("✅ 短信发送成功: " + phone + " - " + code);
                return true;
            } else {
                System.err.println("❌ 短信发送失败: " + response.getBody().getMessage());
                return false;
            }

        } catch (Exception e) {
            System.err.println("❌ 短信发送异常: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * 发送通知短信
     * @param phone 手机号
     * @param templateCode 模板CODE
     * @param templateParam 模板参数（JSON格式）
     * @return 是否发送成功
     */
    public boolean sendNotification(String phone, String templateCode, String templateParam) {
        try {
            Config config = new Config()
                    .setAccessKeyId(accessKeyId)
                    .setAccessKeySecret(accessKeySecret)
                    .setRegionId(regionId)
                    .setEndpoint("dysmsapi.aliyuncs.com");

            Client client = new Client(config);

            SendSmsRequest sendSmsRequest = new SendSmsRequest()
                    .setPhoneNumbers(phone)
                    .setSignName(signName)
                    .setTemplateCode(templateCode)
                    .setTemplateParam(templateParam);

            SendSmsResponse response = client.sendSms(sendSmsRequest);

            if ("OK".equals(response.getBody().getCode())) {
                System.out.println("✅ 通知短信发送成功: " + phone);
                return true;
            } else {
                System.err.println("❌ 通知短信发送失败: " + response.getBody().getMessage());
                return false;
            }

        } catch (Exception e) {
            System.err.println("❌ 通知短信发送异常: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
}
