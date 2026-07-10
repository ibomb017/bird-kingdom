package com.birdkingdom.smsproxy;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SmsProxyApplication {

    public static void main(String[] args) {
        SpringApplication.run(SmsProxyApplication.class, args);
        System.out.println("🚀 SMS代理服务启动成功！端口: 8081");
        System.out.println("📱 短信发送接口: POST /internal/sms/send");
    }
}
