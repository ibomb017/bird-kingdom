package com.birdkingdom.smsproxy.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.mail.*;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.util.Properties;

/**
 * 邮件发送服务
 * 使用SMTP协议发送邮件
 */
@Service
public class EmailService {

    @Value("${email.smtp.host:smtp.163.com}")
    private String smtpHost;

    @Value("${email.smtp.port:465}")
    private int smtpPort;

    @Value("${email.sender:birdkingdom@163.com}")
    private String senderEmail;

    @Value("${email.password:}")
    private String emailPassword;

    @Value("${email.receiver:ibomb017@gmail.com}")
    private String receiverEmail;

    /**
     * 发送反馈邮件
     */
    public EmailResult sendFeedbackEmail(String feedbackType, String content, String contactInfo, Long userId) {
        try {
            // 配置SMTP属性
            Properties props = new Properties();
            props.put("mail.smtp.host", smtpHost);
            props.put("mail.smtp.port", String.valueOf(smtpPort));
            props.put("mail.smtp.auth", "true");
            props.put("mail.smtp.ssl.enable", "true");
            props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");

            // 创建会话
            Session session = Session.getInstance(props, new Authenticator() {
                @Override
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(senderEmail, emailPassword);
                }
            });

            // 创建邮件
            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(senderEmail, "鸟鸟王国反馈"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(receiverEmail));

            // 设置邮件标题
            String typeLabel = getTypeLabel(feedbackType);
            message.setSubject("【鸟鸟王国】用户反馈 - " + typeLabel);

            // 设置邮件内容
            StringBuilder body = new StringBuilder();
            body.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
            body.append("🐦 鸟鸟王国 - 用户反馈\n");
            body.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n");
            body.append("📋 反馈类型: ").append(typeLabel).append("\n\n");
            body.append("📝 反馈内容:\n").append(content).append("\n\n");
            if (contactInfo != null && !contactInfo.isEmpty()) {
                body.append("📞 联系方式: ").append(contactInfo).append("\n\n");
            }
            if (userId != null) {
                body.append("👤 用户ID: ").append(userId).append("\n\n");
            }
            body.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
            body.append("此邮件由系统自动发送，请勿直接回复。\n");

            message.setText(body.toString());

            // 发送邮件
            Transport.send(message);

            System.out.println("📧 邮件发送成功: " + receiverEmail);
            return new EmailResult(true, "邮件发送成功");

        } catch (Exception e) {
            System.err.println("📧 邮件发送失败: " + e.getMessage());
            e.printStackTrace();
            return new EmailResult(false, "邮件发送失败: " + e.getMessage());
        }
    }

    /**
     * 发送通用通知邮件
     * 
     * @param subject 邮件标题
     * @param body    邮件正文
     * @param toEmail 收件人（为空则使用默认收件人）
     */
    public EmailResult sendNotificationEmail(String subject, String body, String toEmail) {
        try {
            Properties props = new Properties();
            props.put("mail.smtp.host", smtpHost);
            props.put("mail.smtp.port", String.valueOf(smtpPort));
            props.put("mail.smtp.auth", "true");
            props.put("mail.smtp.ssl.enable", "true");
            props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");

            Session session = Session.getInstance(props, new Authenticator() {
                @Override
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(senderEmail, emailPassword);
                }
            });

            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(senderEmail, "鸟鸟王国系统通知"));
            String recipient = (toEmail != null && !toEmail.isEmpty()) ? toEmail : receiverEmail;
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(recipient));
            message.setSubject(subject);
            message.setText(body);

            Transport.send(message);

            System.out.println("📧 通知邮件发送成功: " + recipient + " - " + subject);
            return new EmailResult(true, "邮件发送成功");

        } catch (Exception e) {
            System.err.println("📧 通知邮件发送失败: " + e.getMessage());
            e.printStackTrace();
            return new EmailResult(false, "邮件发送失败: " + e.getMessage());
        }
    }

    private String getTypeLabel(String type) {
        if (type == null)
            return "其他";
        switch (type.toLowerCase()) {
            case "bug":
                return "问题反馈";
            case "suggestion":
                return "功能建议";
            case "other":
                return "其他";
            default:
                return type;
        }
    }

    /**
     * 邮件发送结果
     */
    public static class EmailResult {
        private final boolean success;
        private final String message;

        public EmailResult(boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        public boolean isSuccess() {
            return success;
        }

        public String getMessage() {
            return message;
        }
    }
}
