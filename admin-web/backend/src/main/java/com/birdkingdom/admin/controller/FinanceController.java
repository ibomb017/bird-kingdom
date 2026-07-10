package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.repository.SplashDisplaySlotRepository;
import com.birdkingdom.admin.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;

/**
 * 财务管理Controller - 订单、收入统计
 */
@RestController
@RequestMapping("/api/admin/finance")
public class FinanceController {

    @Autowired
    private SplashDisplaySlotRepository splashRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * 收入统计
     */
    @GetMapping("/income")
    public ResponseEntity<Map<String, Object>> getIncome(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {

        // 简化版：基于开屏订单统计
        long totalOrders = splashRepository.count();
        double splashRevenue = totalOrders * 9.90;

        long vipUsers = userRepository.countByIsVipTrue();
        double estimatedVipRevenue = vipUsers * 12.0; // 估算月费

        Map<String, Object> income = new HashMap<>();
        income.put("splashRevenue", String.format("%.2f", splashRevenue));
        income.put("vipRevenue", String.format("%.2f", estimatedVipRevenue));
        income.put("totalRevenue", String.format("%.2f", splashRevenue + estimatedVipRevenue));
        income.put("splashOrders", totalOrders);
        income.put("vipSubscriptions", vipUsers);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", income));
    }

    /**
     * VIP订单列表
     */
    @GetMapping("/vip-orders")
    public ResponseEntity<Map<String, Object>> getVipOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        // 简化版：返回VIP用户列表作为订单
        List<Map<String, Object>> orders = new ArrayList<>();

        // TODO: 实际应该有专门的VIP订单表
        Map<String, Object> result = new HashMap<>();
        result.put("content", orders);
        result.put("totalElements", 0);
        result.put("totalPages", 0);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
    }

    /**
     * 每日收入趋势
     */
    @GetMapping("/daily-revenue")
    public ResponseEntity<Map<String, Object>> getDailyRevenue() {
        List<Map<String, Object>> dailyData = new ArrayList<>();

        for (int i = 6; i >= 0; i--) {
            LocalDate date = LocalDate.now().minusDays(i);

            Map<String, Object> dayData = new HashMap<>();
            dayData.put("date", date.toString());
            dayData.put("revenue", 0.0); // TODO: 实际统计
            dayData.put("orders", 0);
            dailyData.add(dayData);
        }

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", dailyData));
    }
}
