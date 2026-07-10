package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

/**
 * 统计分析扩展Controller - 商业级数据分析
 */
@RestController
@RequestMapping("/api/admin/stats")
public class StatsExtController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ForumPostRepository forumPostRepository;

    @Autowired
    private SplashDisplaySlotRepository splashRepository;

    /**
     * 综合概览数据
     */
    @GetMapping("/overview")
    public ResponseEntity<Map<String, Object>> getOverview() {
        Map<String, Object> overview = new HashMap<>();

        // 用户数据
        long totalUsers = userRepository.count();
        long vipUsers = userRepository.countByIsVipTrue();
        LocalDateTime today = LocalDateTime.now().withHour(0).withMinute(0).withSecond(0);
        long todayNew = userRepository.countTodayNew(today);

        Map<String, Object> userStats = new HashMap<>();
        userStats.put("total", totalUsers);
        userStats.put("vip", vipUsers);
        userStats.put("todayNew", todayNew);
        userStats.put("vipRate", totalUsers > 0 ? String.format("%.2f%%", vipUsers * 100.0 / totalUsers) : "0%");
        overview.put("users", userStats);

        // 内容数据
        long totalPosts = forumPostRepository.count();
        Map<String, Object> contentStats = new HashMap<>();
        contentStats.put("totalPosts", totalPosts);
        contentStats.put("todayPosts", 0); // TODO: 实现今日发帖统计
        overview.put("content", contentStats);

        // 开屏数据
        long pendingSplash = splashRepository.countByReviewStatus("PENDING");
        long approvedSplash = splashRepository.countByReviewStatus("APPROVED");
        Map<String, Object> splashStats = new HashMap<>();
        splashStats.put("pending", pendingSplash);
        splashStats.put("approved", approvedSplash);
        overview.put("splash", splashStats);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", overview));
    }

    /**
     * 用户增长趋势（最近7天）
     */
    @GetMapping("/user-growth")
    public ResponseEntity<Map<String, Object>> getUserGrowth() {
        List<Map<String, Object>> growth = new ArrayList<>();

        for (int i = 6; i >= 0; i--) {
            LocalDateTime dayStart = LocalDateTime.now().minusDays(i).withHour(0).withMinute(0).withSecond(0);
            LocalDateTime dayEnd = dayStart.withHour(23).withMinute(59).withSecond(59);

            long count = userRepository.countByCreatedAtBetween(dayStart, dayEnd);

            Map<String, Object> dayData = new HashMap<>();
            dayData.put("date", dayStart.toLocalDate().toString());
            dayData.put("count", count);
            growth.add(dayData);
        }

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", growth));
    }

    /**
     * VIP转化率分析
     */
    @GetMapping("/vip-conversion")
    public ResponseEntity<Map<String, Object>> getVipConversion() {
        long totalUsers = userRepository.count();
        long vipUsers = userRepository.countByIsVipTrue();
        long coupleVipUsers = userRepository.countByCouplePartnerIdNotNull();

        Map<String, Object> conversion = new HashMap<>();
        conversion.put("totalUsers", totalUsers);
        conversion.put("vipUsers", vipUsers);
        conversion.put("coupleVipUsers", coupleVipUsers);
        conversion.put("vipRate", totalUsers > 0 ? String.format("%.2f%%", vipUsers * 100.0 / totalUsers) : "0%");
        conversion.put("coupleVipRate",
                totalUsers > 0 ? String.format("%.2f%%", coupleVipUsers * 100.0 / totalUsers) : "0%");

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", conversion));
    }

    /**
     * 内容发布趋势
     */
    @GetMapping("/content-trends")
    public ResponseEntity<Map<String, Object>> getContentTrends() {
        Map<String, Object> trends = new HashMap<>();

        long totalPosts = forumPostRepository.count();
        trends.put("totalPosts", totalPosts);

        // TODO: 按照类型统计
        trends.put("postTypes", Map.of(
                "NORMAL", totalPosts,
                "LOST", 0,
                "OTHER", 0));

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", trends));
    }

    /**
     * 财务数据概览
     */
    @GetMapping("/revenue")
    public ResponseEntity<Map<String, Object>> getRevenue() {
        // 简化版：从开屏订单估算收入
        long totalSlots = splashRepository.count();
        double estimatedRevenue = totalSlots * 9.90;

        Map<String, Object> revenue = new HashMap<>();
        revenue.put("totalRevenue", String.format("%.2f", estimatedRevenue));
        revenue.put("totalOrders", totalSlots);
        revenue.put("avgOrderValue", "9.90");

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", revenue));
    }
}
