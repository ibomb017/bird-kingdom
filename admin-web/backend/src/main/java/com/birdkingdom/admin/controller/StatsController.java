package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.SplashDisplaySlot;
import com.birdkingdom.admin.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping({ "/api/stats", "/api/admin/stats" })
public class StatsController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BirdRepository birdRepository;

    @Autowired
    private ForumPostRepository forumPostRepository;

    @Autowired
    private ForumCommentRepository forumCommentRepository;

    @Autowired
    private SplashDisplaySlotRepository splashRepository;

    @GetMapping("/dashboard")
    public ResponseEntity<Map<String, Object>> getDashboardStats() {
        // Real Overview
        Map<String, Object> overview = new HashMap<>();
        overview.put("totalUsers", userRepository.count());
        overview.put("totalBirds", birdRepository.count());
        overview.put("totalPosts", forumPostRepository.count());
        overview.put("totalComments", forumCommentRepository.count());

        // Real Cards
        LocalDateTime startOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MIN);
        List<Map<String, Object>> cards = new ArrayList<>();
        cards.add(Map.of("title", "今日新增用户", "value", userRepository.countTodayNew(startOfDay)));
        cards.add(Map.of("title", "今日发帖", "value", forumPostRepository.countTodayPosts(startOfDay)));

        Map<String, Object> data = new HashMap<>();
        data.put("overview", overview);
        data.put("cards", cards);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", data));
    }

    @GetMapping("/todos")
    public ResponseEntity<Map<String, Object>> getTodos() {
        List<Map<String, Object>> todos = new ArrayList<>();

        // Splash Review Todos
        PageRequest pageRequest = PageRequest.of(0, 5, Sort.by(Sort.Direction.ASC, "createdAt"));
        List<SplashDisplaySlot> pendingSplash = splashRepository.findByReviewStatus("PENDING", pageRequest)
                .getContent();

        if (!pendingSplash.isEmpty()) {
            Map<String, Object> todo1 = new HashMap<>();
            todo1.put("id", "splash-review");
            todo1.put("type", "splash_review");
            todo1.put("title", "开屏展示位审核");
            todo1.put("content", "待审核: " + splashRepository.countByReviewStatus("PENDING") + " 条");
            todo1.put("createdAt", pendingSplash.get(0).getCreatedAt().toString());
            todo1.put("actionUrl", "/splash/review");
            todo1.put("path", "/splash/review");
            todo1.put("count", pendingSplash.size());
            todos.add(todo1);
        }

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", todos));
    }

    @GetMapping("/user-trend")
    public ResponseEntity<Map<String, Object>> getUserTrend(@RequestParam(defaultValue = "7") int days) {
        List<String> dates = new ArrayList<>();
        List<Long> newUsers = new ArrayList<>();
        List<Long> totalUsers = new ArrayList<>();
        List<Long> activeUsers = new ArrayList<>(); // Active users requires log analysis, mocking/estimating for now or
                                                    // query logs

        LocalDate today = LocalDate.now();
        // Calculate cumulative totals backwards? No, forward is better.
        // Get total as of (today - days)
        LocalDateTime startDate = LocalDateTime.of(today.minusDays(days), LocalTime.MAX);
        long currentTotal = userRepository.countByCreatedAtBefore(startDate);

        for (int i = days - 1; i >= 0; i--) {
            LocalDate date = today.minusDays(i);
            dates.add(date.format(DateTimeFormatter.ofPattern("MM-dd")));

            LocalDateTime dayStart = LocalDateTime.of(date, LocalTime.MIN);
            LocalDateTime dayEnd = LocalDateTime.of(date, LocalTime.MAX);

            long count = userRepository.countByCreatedAtBetween(dayStart, dayEnd);
            currentTotal += count;

            newUsers.add(count);
            totalUsers.add(currentTotal);
            // activeUsers: UserActivityLogRepository if available.
            activeUsers.add(0L); // Placeholder until Activity Log implemented
        }

        Map<String, Object> trendData = new HashMap<>();
        trendData.put("dates", dates);
        trendData.put("newUsers", newUsers);
        trendData.put("totalUsers", totalUsers);
        trendData.put("activeUsers", activeUsers);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", trendData));
    }

    @GetMapping("/post-distribution")
    public ResponseEntity<Map<String, Object>> getPostDistribution() {
        List<Object[]> rawStats = forumPostRepository.countByPostType();
        List<Map<String, Object>> dist = new ArrayList<>();

        // Define colors
        Map<String, String> colors = Map.of(
                "NORMAL", "#EC4899",
                "HELP", "#F59E0B",
                "SHOW", "#3B82F6",
                "OTHER", "#10B981");

        for (Object[] row : rawStats) {
            String type = (String) row[0];
            Long count = (Long) row[1];

            String name = type;
            if ("NORMAL".equals(type))
                name = "日常分享";
            else if ("HELP".equals(type))
                name = "求助问答";
            else if ("SHOW".equals(type))
                name = "鸟儿展示";

            dist.add(Map.of("value", count, "name", name, "color", colors.getOrDefault(type, "#9CA3AF")));
        }

        if (dist.isEmpty()) {
            dist.add(Map.of("value", 0, "name", "无数据", "color", "#E5E7EB"));
        }

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", dist));
    }

    @GetMapping("/revenue-trend")
    public ResponseEntity<Map<String, Object>> getRevenueTrend(@RequestParam(defaultValue = "7") int days) {
        List<String> dates = new ArrayList<>();
        List<Double> vipRevenue = new ArrayList<>();
        List<Double> splashRevenue = new ArrayList<>();

        LocalDate today = LocalDate.now();

        for (int i = days - 1; i >= 0; i--) {
            LocalDate date = today.minusDays(i);
            dates.add(date.format(DateTimeFormatter.ofPattern("MM-dd")));

            // Splash revenue: count approved slots for each day * 9.9
            long dailySplashSlots = splashRepository.countByDisplayDateAndStatus(date, "APPROVED");
            splashRevenue.add(dailySplashSlots * 9.90);

            // VIP revenue: placeholder until VIP payment system is implemented
            vipRevenue.add(0.0);
        }

        Map<String, Object> trendData = new HashMap<>();
        trendData.put("dates", dates);
        trendData.put("vipRevenue", vipRevenue);
        trendData.put("splashRevenue", splashRevenue);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", trendData));
    }
}
