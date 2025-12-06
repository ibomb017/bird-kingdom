package com.birdkingdom.service;

import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Date;

@Service
public class NeteaseSmsService {

    @Value("${netease.sms.app-key}")
    private String appKey;

    @Value("${netease.sms.app-secret}")
    private String appSecret;

    @Value("${netease.sms.template-id:3055603}")
    private String templateId;

    private static final String API_URL = "https://api.netease.im/sms/sendcode.action";

    /**
     * 发送短信验证码
     * @param phone 手机号
     * @param code 验证码
     * @return 是否发送成功
     */
    public boolean sendVerificationCode(String phone, String code) {
        try {
            // 构建请求
            CloseableHttpClient httpClient = HttpClients.createDefault();
            HttpPost httpPost = new HttpPost(API_URL);

            // 设置请求头
            String nonce = String.valueOf(new Date().getTime());
            String curTime = String.valueOf(System.currentTimeMillis() / 1000);
            String checkSum = getCheckSum(appSecret, nonce, curTime);

            httpPost.setHeader("AppKey", appKey);
            httpPost.setHeader("Nonce", nonce);
            httpPost.setHeader("CurTime", curTime);
            httpPost.setHeader("CheckSum", checkSum);
            httpPost.setHeader("Content-Type", "application/x-www-form-urlencoded;charset=utf-8");

            // 设置请求参数
            String params = "mobile=" + phone + "&templateid=" + templateId + "&authCode=" + code;
            httpPost.setEntity(new StringEntity(params, StandardCharsets.UTF_8));

            // 发送请求
            HttpResponse response = httpClient.execute(httpPost);
            String result = EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);

            // 解析响应
            if (result.contains("\"code\":200")) {
                System.out.println("✅ 网易云短信发送成功: " + phone + " - " + code);
                return true;
            } else {
                System.err.println("❌ 网易云短信发送失败: " + result);
                return false;
            }

        } catch (Exception e) {
            System.err.println("❌ 网易云短信发送异常: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * 计算CheckSum
     */
    private String getCheckSum(String appSecret, String nonce, String curTime) {
        try {
            String str = appSecret + nonce + curTime;
            MessageDigest md = MessageDigest.getInstance("SHA-1");
            byte[] digest = md.digest(str.getBytes(StandardCharsets.UTF_8));
            return bytesToHex(digest);
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

    /**
     * 字节数组转十六进制字符串
     */
    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
