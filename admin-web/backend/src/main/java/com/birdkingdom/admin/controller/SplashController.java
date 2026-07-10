package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.SplashDisplaySlot;
import com.birdkingdom.admin.entity.User;
import com.birdkingdom.admin.entity.SplashOrder;
import com.birdkingdom.admin.repository.SplashDisplaySlotRepository;
import com.birdkingdom.admin.repository.SplashOrderRepository;
import com.birdkingdom.admin.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.*;

/**
 * 开屏庆生审核控制器 - 真实数据
 */
@RestController
@RequestMapping({ "/api/splash", "/api/admin/splash" })
public class SplashController {

    @Autowired
    private SplashDisplaySlotRepository splashRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SplashOrderRepository orderRepository;

    /**
     * 获取待审核列表
     */
    @GetMapping({ "/pending-review", "/admin/reviews", "/reviews" })
    public ResponseEntity<Map<String, Object>> getPendingReview(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "displayDate"));
        Page<SplashDisplaySlot> slotPage;
        if (status != null && !status.isEmpty()) {
            slotPage = splashRepository.findByReviewStatus(status, pageRequest);
        } else {
            slotPage = splashRepository.findByReviewStatus("PENDING", pageRequest);
        }

        List<Map<String, Object>> pendingList = new ArrayList<>();
        for (SplashDisplaySlot slot : slotPage.getContent()) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", slot.getId());
            item.put("userId", slot.getUserId());
            item.put("displayDate", slot.getDisplayDate());
            item.put("imageUrl", slot.getImageUrl());
            item.put("slotNumber", slot.getSlotNumber());
            item.put("reviewStatus", slot.getReviewStatus());
            item.put("status", slot.getStatus());
            item.put("createdAt", slot.getCreatedAt());

            // 获取用户信息
            if (slot.getUserId() != null) {
                userRepository.findById(slot.getUserId()).ifPresent(user -> {
                    item.put("userNickname", user.getNickname());
                    item.put("userPhone", maskPhone(user.getPhone()));
                    item.put("userAvatarUrl", user.getAvatarUrl());
                });
            }

            pendingList.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", pendingList);
        result.put("totalElements", slotPage.getTotalElements());
        result.put("totalPages", slotPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 获取所有展示位列表
     */
    @GetMapping("/slots")
    public ResponseEntity<Map<String, Object>> getSlots(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "displayDate"));
        Page<SplashDisplaySlot> slotPage;

        // status参数实际是reviewStatus（审核状态）
        if (status != null && !status.isEmpty()) {
            slotPage = splashRepository.findByReviewStatus(status, pageRequest);
        } else {
            slotPage = splashRepository.findAll(pageRequest);
        }

        List<Map<String, Object>> slots = new ArrayList<>();
        for (SplashDisplaySlot slot : slotPage.getContent()) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", slot.getId());
            item.put("userId", slot.getUserId());
            item.put("displayDate", slot.getDisplayDate());
            item.put("imageUrl", slot.getImageUrl());
            item.put("slotNumber", slot.getSlotNumber());
            item.put("reviewStatus", slot.getReviewStatus());
            item.put("status", slot.getStatus());
            item.put("orderId", slot.getOrderId());
            item.put("createdAt", slot.getCreatedAt());

            // 获取用户信息
            if (slot.getUserId() != null) {
                userRepository.findById(slot.getUserId()).ifPresent(user -> {
                    item.put("userNickname", user.getNickname());
                });
            }

            slots.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", slots);
        result.put("totalElements", slotPage.getTotalElements());
        result.put("totalPages", slotPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 审核通过
     */
    @PostMapping({ "/{id}/approve", "/reviews/{id}/approve" })
    public ResponseEntity<Map<String, Object>> approve(@PathVariable Long id) {
        Optional<SplashDisplaySlot> slotOpt = splashRepository.findById(id);
        if (slotOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "展示位不存在"));
        }

        SplashDisplaySlot slot = slotOpt.get();
        slot.setReviewStatus("APPROVED");
        slot.setStatus("APPROVED"); // 同步更新 status，供 launch-config 查询
        slot.setReviewedAt(LocalDateTime.now());
        splashRepository.save(slot);

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "审核通过"));
    }

    /**
     * 审核驳回
     */
    @PostMapping({ "/{id}/reject", "/reviews/{id}/reject" })
    public ResponseEntity<Map<String, Object>> reject(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {
        Optional<SplashDisplaySlot> slotOpt = splashRepository.findById(id);
        if (slotOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "展示位不存在"));
        }

        String reason = request.get("reason");
        SplashDisplaySlot slot = slotOpt.get();
        slot.setReviewStatus("REJECTED");
        slot.setReviewReason(reason);
        slot.setReviewedAt(LocalDateTime.now());
        slot.setStatus("REJECTED"); // 更新展示位状态
        splashRepository.save(slot);

        // 处理退款：更新订单状态为已退款
        if (slot.getOrderId() != null) {
            orderRepository.findById(slot.getOrderId()).ifPresent(order -> {
                order.setStatus("REFUNDED");
                orderRepository.save(order);
            });
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "已驳回，订单已标记为退款"));
    }

    /**
     * 获取日历数据
     */
    @GetMapping("/calendar")
    public ResponseEntity<Map<String, Object>> getCalendar(
            @RequestParam int year,
            @RequestParam int month) {
        LocalDate firstDay = LocalDate.of(year, month, 1);
        LocalDate lastDay = YearMonth.of(year, month).atEndOfMonth();

        List<Object[]> stats = splashRepository.countByDateRange(firstDay, lastDay);

        Map<String, Map<String, Object>> calendarData = new HashMap<>();
        int daysInMonth = lastDay.getDayOfMonth();

        // 初始化每天
        for (int day = 1; day <= daysInMonth; day++) {
            String dateKey = String.format("%d-%02d-%02d", year, month, day);
            Map<String, Object> dayData = new HashMap<>();
            dayData.put("totalSlots", 10);
            dayData.put("bookedSlots", 0);
            dayData.put("revenue", 0.0);
            calendarData.put(dateKey, dayData);
        }

        // 填充实际数据
        for (Object[] row : stats) {
            LocalDate date = (LocalDate) row[0];
            Long count = (Long) row[1];
            String dateKey = date.toString();
            if (calendarData.containsKey(dateKey)) {
                calendarData.get(dateKey).put("bookedSlots", count.intValue());
                calendarData.get(dateKey).put("revenue", count * 9.90);
            }
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", calendarData));
    }

    /**
     * 获取某天的展示位详情
     */
    @GetMapping("/date/{date}")
    public ResponseEntity<Map<String, Object>> getDateSlots(@PathVariable String date) {
        LocalDate displayDate = LocalDate.parse(date);
        List<SplashDisplaySlot> slots = splashRepository.findByDisplayDate(displayDate);

        List<Map<String, Object>> slotList = new ArrayList<>();
        for (SplashDisplaySlot slot : slots) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", slot.getId());
            item.put("slotNumber", slot.getSlotNumber());
            item.put("imageUrl", slot.getImageUrl());
            item.put("reviewStatus", slot.getReviewStatus());
            item.put("status", slot.getStatus());

            if (slot.getUserId() != null) {
                userRepository.findById(slot.getUserId()).ifPresent(user -> {
                    item.put("userNickname", user.getNickname());
                    item.put("userAvatarUrl", user.getAvatarUrl());
                });
            }

            slotList.add(item);
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", slotList));
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7)
            return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }
}
