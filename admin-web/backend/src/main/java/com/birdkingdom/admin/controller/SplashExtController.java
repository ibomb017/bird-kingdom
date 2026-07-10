package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.SplashDisplaySlot;
import com.birdkingdom.admin.repository.SplashDisplaySlotRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

/**
 * 开屏管理扩展Controller - 补充Delete、配置管理、统计等功能
 */
@RestController
@RequestMapping("/api/admin/splash")
public class SplashExtController {

    @Autowired
    private SplashDisplaySlotRepository splashRepository;

    /**
     * 删除展示位（管理员操作）
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteSlot(@PathVariable Long id) {
        Optional<SplashDisplaySlot> slotOpt = splashRepository.findById(id);
        if (slotOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "展示位不存在"));
        }

        splashRepository.deleteById(id);
        return ResponseEntity.ok(Map.of("code", 0, "message", "删除成功"));
    }

    /**
     * 修改展示位状态（上线/下线）
     */
    @PutMapping("/{id}/status")
    public ResponseEntity<Map<String, Object>> updateSlotStatus(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {
        Optional<SplashDisplaySlot> slotOpt = splashRepository.findById(id);
        if (slotOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "展示位不存在"));
        }

        String status = request.get("status"); // ACTIVE, INACTIVE, EXPIRED
        SplashDisplaySlot slot = slotOpt.get();
        slot.setStatus(status);
        splashRepository.save(slot);

        return ResponseEntity.ok(Map.of("code", 0, "message", "状态更新成功"));
    }

    /**
     * 批量审核通过
     */
    @PostMapping("/batch-approve")
    public ResponseEntity<Map<String, Object>> batchApprove(@RequestBody Map<String, Object> request) {
        @SuppressWarnings("unchecked")
        List<Long> ids = (List<Long>) request.get("ids");
        if (ids == null || ids.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "请选择待审核条目"));
        }

        int successCount = 0;
        for (Long id : ids) {
            Optional<SplashDisplaySlot> slotOpt = splashRepository.findById(id);
            if (slotOpt.isPresent()) {
                SplashDisplaySlot slot = slotOpt.get();
                slot.setReviewStatus("APPROVED");
                slot.setStatus("APPROVED"); // 同步更新 status
                slot.setReviewedAt(LocalDateTime.now());
                splashRepository.save(slot);
                successCount++;
            }
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "批量审核完成",
                "data", Map.of("successCount", successCount)));
    }

    /**
     * 获取名额配置（当前按固定10个/天返回）
     */
    @GetMapping("/quota")
    public ResponseEntity<Map<String, Object>> getQuota() {
        Map<String, Object> quota = new HashMap<>();
        quota.put("dailySlots", 10); // 每日可预订名额
        quota.put("price", 9.90); // 单价
        quota.put("description", "每日开屏庆生展示位名额");
        quota.put("enabled", true);

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", quota));
    }

    /**
     * 更新名额配置
     */
    @PutMapping("/quota")
    public ResponseEntity<Map<String, Object>> updateQuota(@RequestBody Map<String, Object> request) {
        // 此功能在简化版中只返回成功，实际可以存储到配置表
        Integer dailySlots = (Integer) request.get("dailySlots");
        Double price = (Double) request.get("price");
        Boolean enabled = (Boolean) request.get("enabled");

        // TODO: 存储到系统配置表

        return ResponseEntity.ok(Map.of("code", 0, "message", "配置更新成功"));
    }

    /**
     * 获取统计数据
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getStatistics(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {

        LocalDate start = startDate != null ? LocalDate.parse(startDate) : LocalDate.now().minusMonths(1);
        LocalDate end = endDate != null ? LocalDate.parse(endDate) : LocalDate.now();

        long totalSlots = splashRepository.count();
        long pendingReview = splashRepository.countByReviewStatus("PENDING");
        long approved = splashRepository.countByReviewStatus("APPROVED");
        long rejected = splashRepository.countByReviewStatus("REJECTED");

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalSlots", totalSlots);
        stats.put("pendingReview", pendingReview);
        stats.put("approved", approved);
        stats.put("rejected", rejected);
        stats.put("approvalRate", totalSlots > 0 ? String.format("%.2f%%", approved * 100.0 / totalSlots) : "0%");

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", stats));
    }

    /**
     * 获取订单列表（从splash_display_slot获取）
     */
    @GetMapping("/orders")
    public ResponseEntity<Map<String, Object>> getOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        // 简化版：从展示位数据生成订单视图
        List<SplashDisplaySlot> slots = splashRepository.findAll();

        List<Map<String, Object>> orders = new ArrayList<>();
        for (SplashDisplaySlot slot : slots) {
            Map<String, Object> order = new HashMap<>();
            order.put("orderId", slot.getOrderId());
            order.put("displayDate", slot.getDisplayDate());
            order.put("amount", 9.90);
            order.put("status", slot.getStatus());
            order.put("reviewStatus", slot.getReviewStatus());
            order.put("createdAt", slot.getCreatedAt());
            orders.add(order);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", orders);
        result.put("totalElements", orders.size());
        result.put("totalPages", (int) Math.ceil(orders.size() / (double) size));

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
    }
}
