package com.birdkingdom.smsproxy.controller;

import com.birdkingdom.smsproxy.service.AliyunSmsService;
import com.birdkingdom.smsproxy.service.SmsRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 短信代理控制器
 * 接收来自新加坡服务器的短信发送请求，转发到阿里云短信服务
 * 
 * 安全机制：
 * - 集成 SmsRateLimiter 防止短信轰炸
 * - 支持接收上游传递的客户端真实 IP
 */
@RestController
@RequestMapping("/internal/sms")
public class SmsController {

    private final AliyunSmsService aliyunSmsService;
    private final SmsRateLimiter smsRateLimiter;

    public SmsController(AliyunSmsService aliyunSmsService, SmsRateLimiter smsRateLimiter) {
        this.aliyunSmsService = aliyunSmsService;
        this.smsRateLimiter = smsRateLimiter;
    }

    /**
     * 发送短信验证码
     * 
     * 请求头：
     * - X-API-Key: your-api-key
     * - X-Forwarded-For: 客户端真实IP（由上游服务传递）
     * - X-Real-IP: 客户端真实IP（备用）
     * 
     * 请求体：{"phone": "13587877696", "code": "123456", "clientIp": "可选-客户端IP"}
     */
    @PostMapping("/send")
    public ResponseEntity<Map<String, Object>> sendSms(
            @RequestBody SmsRequest request,
            HttpServletRequest httpRequest) {
        Map<String, Object> result = new HashMap<>();

        // 参数校验
        if (request.getPhone() == null || request.getPhone().isEmpty()) {
            result.put("success", false);
            result.put("message", "手机号不能为空");
            return ResponseEntity.badRequest().body(result);
        }

        if (request.getCode() == null || request.getCode().isEmpty()) {
            result.put("success", false);
            result.put("message", "验证码不能为空");
            return ResponseEntity.badRequest().body(result);
        }

        // 获取客户端IP（优先使用请求体中传递的IP，其次从请求头获取）
        String clientIp = getClientIp(request, httpRequest);

        // 🔒 频率限制检查
        SmsRateLimiter.RateLimitResult rateLimitResult = smsRateLimiter.checkRateLimit(
                request.getPhone(), clientIp);

        if (!rateLimitResult.isAllowed()) {
            System.out.println("⚠️ 短信频率限制触发: phone=" + request.getPhone() +
                    ", ip=" + clientIp + ", reason=" + rateLimitResult.getMessage());
            result.put("success", false);
            result.put("message", rateLimitResult.getMessage());
            if (rateLimitResult.getRetryAfterSeconds() > 0) {
                result.put("retryAfterSeconds", rateLimitResult.getRetryAfterSeconds());
            }
            return ResponseEntity.status(429).body(result); // Too Many Requests
        }

        // 发送短信
        System.out.println("📱 收到短信发送请求: " + request.getPhone() + " -> " + request.getCode() +
                " (IP: " + clientIp + ")");
        AliyunSmsService.SmsResult smsResult = aliyunSmsService.sendVerificationCode(
                request.getPhone(),
                request.getCode());

        // 发送成功后记录（即使发送失败也不记录，避免恶意触发限流）
        if (smsResult.isSuccess()) {
            smsRateLimiter.recordSend(request.getPhone(), clientIp);
        }

        result.put("success", smsResult.isSuccess());
        result.put("message", smsResult.getMessage());

        return ResponseEntity.ok(result);
    }

    /**
     * 获取客户端真实IP
     * 优先级：请求体参数 > X-Forwarded-For > X-Real-IP > RemoteAddr
     */
    private String getClientIp(SmsRequest request, HttpServletRequest httpRequest) {
        // 1. 请求体中传递的IP（上游Swift后端传递）
        if (request.getClientIp() != null && !request.getClientIp().isEmpty()) {
            return request.getClientIp();
        }

        // 2. X-Forwarded-For 头（可能包含多个IP，取第一个）
        String xForwardedFor = httpRequest.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            String[] ips = xForwardedFor.split(",");
            return ips[0].trim();
        }

        // 3. X-Real-IP 头
        String xRealIp = httpRequest.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }

        // 4. 直接获取远程地址
        return httpRequest.getRemoteAddr();
    }

    /**
     * 健康检查接口
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "UP");
        result.put("service", "sms-proxy");
        return ResponseEntity.ok(result);
    }

    /**
     * 短信请求体
     */
    public static class SmsRequest {
        private String phone;
        private String code;
        private String clientIp; // 可选：客户端真实IP（上游服务传递）

        public String getPhone() {
            return phone;
        }

        public void setPhone(String phone) {
            this.phone = phone;
        }

        public String getCode() {
            return code;
        }

        public void setCode(String code) {
            this.code = code;
        }

        public String getClientIp() {
            return clientIp;
        }

        public void setClientIp(String clientIp) {
            this.clientIp = clientIp;
        }
    }
}
