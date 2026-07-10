package com.birdkingdom.smsproxy.service;

import org.springframework.stereotype.Service;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * 短信发送频率限制服务
 * 防止短信轰炸和资源滥用
 * 
 * 限制策略：
 * 1. 同一手机号：60秒内只能发送1条
 * 2. 同一手机号：1小时内最多发送5条
 * 3. 同一手机号：24小时内最多发送10条
 * 4. 同一IP：1分钟内最多发送3条
 * 5. 同一IP：1小时内最多发送20条
 */
@Service
public class SmsRateLimiter {

    // 手机号频率限制记录
    private final ConcurrentHashMap<String, RateLimitRecord> phoneRecords = new ConcurrentHashMap<>();

    // IP频率限制记录
    private final ConcurrentHashMap<String, RateLimitRecord> ipRecords = new ConcurrentHashMap<>();

    // 单次发送间隔（毫秒）
    private static final long SINGLE_INTERVAL_MS = 60 * 1000; // 60秒

    // 小时级限制
    private static final int HOURLY_PHONE_LIMIT = 5;
    private static final int HOURLY_IP_LIMIT = 20;
    private static final long HOUR_MS = 60 * 60 * 1000;

    // 天级限制
    private static final int DAILY_PHONE_LIMIT = 10;
    private static final long DAY_MS = 24 * 60 * 60 * 1000;

    // 分钟级IP限制
    private static final int MINUTE_IP_LIMIT = 3;
    private static final long MINUTE_MS = 60 * 1000;

    /**
     * 检查是否允许发送短信
     * 
     * @param phone    手机号
     * @param clientIp 客户端IP（可选）
     * @return 检查结果
     */
    public RateLimitResult checkRateLimit(String phone, String clientIp) {
        long now = System.currentTimeMillis();

        // 检查手机号限制
        RateLimitResult phoneResult = checkPhoneLimit(phone, now);
        if (!phoneResult.isAllowed()) {
            return phoneResult;
        }

        // 检查IP限制（如果提供了IP）
        if (clientIp != null && !clientIp.isEmpty()) {
            RateLimitResult ipResult = checkIpLimit(clientIp, now);
            if (!ipResult.isAllowed()) {
                return ipResult;
            }
        }

        return new RateLimitResult(true, null, 0);
    }

    /**
     * 记录一次成功的短信发送
     */
    public void recordSend(String phone, String clientIp) {
        long now = System.currentTimeMillis();

        // 记录手机号发送
        phoneRecords.compute(phone, (k, v) -> {
            if (v == null) {
                v = new RateLimitRecord();
            }
            v.addRecord(now);
            return v;
        });

        // 记录IP发送
        if (clientIp != null && !clientIp.isEmpty()) {
            ipRecords.compute(clientIp, (k, v) -> {
                if (v == null) {
                    v = new RateLimitRecord();
                }
                v.addRecord(now);
                return v;
            });
        }
    }

    private RateLimitResult checkPhoneLimit(String phone, long now) {
        RateLimitRecord record = phoneRecords.get(phone);
        if (record == null) {
            return new RateLimitResult(true, null, 0);
        }

        // 清理过期记录
        record.cleanExpired(now, DAY_MS);

        // 检查单次间隔
        long lastSendTime = record.getLastSendTime();
        if (lastSendTime > 0) {
            long elapsed = now - lastSendTime;
            if (elapsed < SINGLE_INTERVAL_MS) {
                int waitSeconds = (int) ((SINGLE_INTERVAL_MS - elapsed) / 1000) + 1;
                return new RateLimitResult(false,
                        String.format("发送过于频繁，请%d秒后重试", waitSeconds),
                        waitSeconds);
            }
        }

        // 检查小时级限制
        int hourlyCount = record.getCountInWindow(now, HOUR_MS);
        if (hourlyCount >= HOURLY_PHONE_LIMIT) {
            return new RateLimitResult(false,
                    "该手机号1小时内发送次数已达上限，请稍后重试",
                    0);
        }

        // 检查天级限制
        int dailyCount = record.getCountInWindow(now, DAY_MS);
        if (dailyCount >= DAILY_PHONE_LIMIT) {
            return new RateLimitResult(false,
                    "该手机号24小时内发送次数已达上限，请明天再试",
                    0);
        }

        return new RateLimitResult(true, null, 0);
    }

    private RateLimitResult checkIpLimit(String clientIp, long now) {
        RateLimitRecord record = ipRecords.get(clientIp);
        if (record == null) {
            return new RateLimitResult(true, null, 0);
        }

        // 清理过期记录
        record.cleanExpired(now, HOUR_MS);

        // 检查分钟级限制
        int minuteCount = record.getCountInWindow(now, MINUTE_MS);
        if (minuteCount >= MINUTE_IP_LIMIT) {
            return new RateLimitResult(false,
                    "请求过于频繁，请稍后重试",
                    60);
        }

        // 检查小时级限制
        int hourlyCount = record.getCountInWindow(now, HOUR_MS);
        if (hourlyCount >= HOURLY_IP_LIMIT) {
            return new RateLimitResult(false,
                    "请求次数已达上限，请稍后重试",
                    0);
        }

        return new RateLimitResult(true, null, 0);
    }

    /**
     * 定期清理过期记录（可由定时任务调用）
     */
    public void cleanupExpiredRecords() {
        long now = System.currentTimeMillis();

        phoneRecords.forEach((phone, record) -> {
            record.cleanExpired(now, DAY_MS);
            if (record.isEmpty()) {
                phoneRecords.remove(phone);
            }
        });

        ipRecords.forEach((ip, record) -> {
            record.cleanExpired(now, HOUR_MS);
            if (record.isEmpty()) {
                ipRecords.remove(ip);
            }
        });
    }

    /**
     * 频率限制记录
     */
    private static class RateLimitRecord {
        private final java.util.List<Long> sendTimes = new java.util.ArrayList<>();

        synchronized void addRecord(long timestamp) {
            sendTimes.add(timestamp);
        }

        synchronized long getLastSendTime() {
            if (sendTimes.isEmpty()) {
                return 0;
            }
            return sendTimes.get(sendTimes.size() - 1);
        }

        synchronized int getCountInWindow(long now, long windowMs) {
            long windowStart = now - windowMs;
            return (int) sendTimes.stream()
                    .filter(t -> t >= windowStart)
                    .count();
        }

        synchronized void cleanExpired(long now, long maxAgeMs) {
            long threshold = now - maxAgeMs;
            sendTimes.removeIf(t -> t < threshold);
        }

        synchronized boolean isEmpty() {
            return sendTimes.isEmpty();
        }
    }

    /**
     * 频率限制检查结果
     */
    public static class RateLimitResult {
        private final boolean allowed;
        private final String message;
        private final int retryAfterSeconds;

        public RateLimitResult(boolean allowed, String message, int retryAfterSeconds) {
            this.allowed = allowed;
            this.message = message;
            this.retryAfterSeconds = retryAfterSeconds;
        }

        public boolean isAllowed() {
            return allowed;
        }

        public String getMessage() {
            return message;
        }

        public int getRetryAfterSeconds() {
            return retryAfterSeconds;
        }
    }
}
