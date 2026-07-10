package com.birdkingdom.smsproxy.controller;

import com.birdkingdom.smsproxy.service.EmailService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 邮件代理控制器
 * 接收来自Swift后端的反馈邮件发送请求
 */
@RestController
@RequestMapping("/internal/email")
public class EmailController {

    private final EmailService emailService;

    public EmailController(EmailService emailService) {
        this.emailService = emailService;
    }

    /**
     * 发送反馈邮件
     * 
     * 请求头：X-API-Key: your-api-key
     * 请求体：{"type": "bug", "content": "反馈内容", "contactInfo": "联系方式", "userId": 123}
     */
    @PostMapping("/feedback")
    public ResponseEntity<Map<String, Object>> sendFeedback(@RequestBody FeedbackRequest request) {
        Map<String, Object> result = new HashMap<>();

        // 参数校验
        if (request.getContent() == null || request.getContent().isEmpty()) {
            result.put("success", false);
            result.put("message", "反馈内容不能为空");
            return ResponseEntity.badRequest().body(result);
        }

        // 发送邮件
        System.out.println("📧 收到反馈邮件发送请求: " + request.getType() + " - "
                + request.getContent().substring(0, Math.min(50, request.getContent().length())) + "...");
        EmailService.EmailResult emailResult = emailService.sendFeedbackEmail(
                request.getType(),
                request.getContent(),
                request.getContactInfo(),
                request.getUserId());

        result.put("success", emailResult.isSuccess());
        result.put("message", emailResult.getMessage());

        return ResponseEntity.ok(result);
    }

    /**
     * 发送通用通知邮件
     * 
     * 请求体：{"subject": "标题", "body": "内容", "toEmail": "可选收件人"}
     */
    @PostMapping("/notify")
    public ResponseEntity<Map<String, Object>> sendNotify(@RequestBody Map<String, String> request) {
        Map<String, Object> result = new HashMap<>();

        String subject = request.get("subject");
        String body = request.get("body");
        String toEmail = request.get("toEmail");

        if (subject == null || subject.isEmpty() || body == null || body.isEmpty()) {
            result.put("success", false);
            result.put("message", "标题和内容不能为空");
            return ResponseEntity.badRequest().body(result);
        }

        System.out.println("📧 收到通知邮件发送请求: " + subject);
        EmailService.EmailResult emailResult = emailService.sendNotificationEmail(subject, body, toEmail);

        result.put("success", emailResult.isSuccess());
        result.put("message", emailResult.getMessage());
        return ResponseEntity.ok(result);
    }

    /**
     * 健康检查接口
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "UP");
        result.put("service", "email-proxy");
        return ResponseEntity.ok(result);
    }

    /**
     * 反馈请求体
     */
    public static class FeedbackRequest {
        private String type;
        private String content;
        private String contactInfo;
        private Long userId;

        public String getType() {
            return type;
        }

        public void setType(String type) {
            this.type = type;
        }

        public String getContent() {
            return content;
        }

        public void setContent(String content) {
            this.content = content;
        }

        public String getContactInfo() {
            return contactInfo;
        }

        public void setContactInfo(String contactInfo) {
            this.contactInfo = contactInfo;
        }

        public Long getUserId() {
            return userId;
        }

        public void setUserId(Long userId) {
            this.userId = userId;
        }
    }
}
