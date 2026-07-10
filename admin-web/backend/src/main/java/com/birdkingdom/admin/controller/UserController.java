package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.User;
import com.birdkingdom.admin.entity.Bird;
import com.birdkingdom.admin.repository.UserRepository;
import com.birdkingdom.admin.repository.BirdRepository;
import com.birdkingdom.admin.repository.ForumPostRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * 用户管理控制器 - 真实数据
 */
@RestController
@RequestMapping({ "/api/users", "/api/admin/users" })
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BirdRepository birdRepository;

    @Autowired
    private ForumPostRepository forumPostRepository;

    /**
     * 获取用户列表
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String vipStatus) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<User> userPage;

        if (keyword != null && !keyword.isEmpty()) {
            userPage = userRepository.searchByKeyword(keyword, pageRequest);
        } else if ("vip".equals(vipStatus)) {
            userPage = userRepository.findByIsVipTrue(pageRequest);
        } else if ("couple".equals(vipStatus)) {
            userPage = userRepository.findByIsCoupleVipTrue(pageRequest);
        } else {
            userPage = userRepository.findAll(pageRequest);
        }

        List<Map<String, Object>> users = new ArrayList<>();
        for (User user : userPage.getContent()) {
            Map<String, Object> userMap = new HashMap<>();
            userMap.put("id", user.getId());
            userMap.put("phone", maskPhone(user.getPhone()));
            userMap.put("nickname", user.getNickname());
            userMap.put("avatarUrl", user.getAvatarUrl());
            userMap.put("bio", user.getBio());
            userMap.put("isVip", user.getIsVip());
            userMap.put("vipType", user.getVipType());
            userMap.put("vipExpireDate", user.getVipExpireDate());
            userMap.put("isCoupleVip", user.getIsCoupleVip());
            userMap.put("couplePartnerId", user.getCouplePartnerId());
            userMap.put("createdAt", user.getCreatedAt());
            users.add(userMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", users);
        result.put("totalElements", userPage.getTotalElements());
        result.put("totalPages", userPage.getTotalPages());
        result.put("number", userPage.getNumber());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 导出用户数据到CSV
     */
    @GetMapping("/export")
    public void exportUsers(HttpServletResponse response) throws IOException {
        response.setContentType("text/csv; charset=UTF-8");
        response.setHeader("Content-Disposition", "attachment; filename=\"users_export_" + System.currentTimeMillis() + ".csv\"");
        
        // Write UTF-8 BOM
        response.getOutputStream().write(new byte[]{(byte) 0xEF, (byte) 0xBB, (byte) 0xBF});

        try (PrintWriter writer = new PrintWriter(response.getOutputStream(), false, StandardCharsets.UTF_8)) {
            writer.println("ID,手机号,昵称,是否VIP,VIP类型,VIP到期时间,是否情侣VIP,注册时间");
            
            List<User> users = userRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt"));
            for (User user : users) {
                writer.printf("%d,%s,%s,%s,%s,%s,%s,%s\n",
                        user.getId(),
                        maskPhone(user.getPhone()),
                        user.getNickname() != null ? user.getNickname().replace(",", "，") : "",
                        user.getIsVip() != null && user.getIsVip() ? "是" : "否",
                        user.getVipType() != null ? user.getVipType() : "",
                        user.getVipExpireDate() != null ? user.getVipExpireDate().toString() : "",
                        user.getIsCoupleVip() != null && user.getIsCoupleVip() ? "是" : "否",
                        user.getCreatedAt() != null ? user.getCreatedAt().toString() : ""
                );
            }
            writer.flush();
        }
    }

    /**
     * 获取用户详情
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getUserDetail(@PathVariable Long id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();
        long birdCount = birdRepository.findByUserId(id, PageRequest.of(0, 1)).getTotalElements();
        long postCount = forumPostRepository.findByAuthorId(id, PageRequest.of(0, 1)).getTotalElements();

        Map<String, Object> detail = new HashMap<>();
        detail.put("id", user.getId());
        detail.put("phone", maskPhone(user.getPhone()));
        detail.put("nickname", user.getNickname());
        detail.put("avatarUrl", user.getAvatarUrl());
        detail.put("bio", user.getBio());
        detail.put("isVip", user.getIsVip());
        detail.put("vipType", user.getVipType());
        detail.put("vipExpireDate", user.getVipExpireDate());
        detail.put("isCoupleVip", user.getIsCoupleVip());
        detail.put("couplePartnerId", user.getCouplePartnerId());
        detail.put("createdAt", user.getCreatedAt());
        detail.put("birdCount", birdCount);
        detail.put("postCount", postCount);

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", detail));
    }

    /**
     * 获取VIP用户列表
     */
    @GetMapping("/vip")
    public ResponseEntity<Map<String, Object>> getVipUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String vipType) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "vipExpireDate"));
        Page<User> userPage;

        if (vipType != null && !vipType.isEmpty()) {
            userPage = userRepository.findByVipType(vipType, pageRequest);
        } else {
            userPage = userRepository.findByIsVipTrue(pageRequest);
        }

        List<Map<String, Object>> users = new ArrayList<>();
        for (User user : userPage.getContent()) {
            Map<String, Object> userMap = new HashMap<>();
            userMap.put("id", user.getId());
            userMap.put("phone", maskPhone(user.getPhone()));
            userMap.put("nickname", user.getNickname());
            userMap.put("avatarUrl", user.getAvatarUrl());
            userMap.put("vipType", user.getVipType());
            userMap.put("vipExpireDate", user.getVipExpireDate());
            userMap.put("createdAt", user.getCreatedAt());
            users.add(userMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", users);
        result.put("totalElements", userPage.getTotalElements());
        result.put("totalPages", userPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 获取情侣绑定列表
     */
    @GetMapping("/couples")
    public ResponseEntity<Map<String, Object>> getCouples(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<User> userPage = userRepository.findByIsCoupleVipTrue(pageRequest);

        List<Map<String, Object>> couples = new ArrayList<>();
        for (User user : userPage.getContent()) {
            Map<String, Object> coupleMap = new HashMap<>();
            coupleMap.put("id", user.getId());
            coupleMap.put("nickname", user.getNickname());
            coupleMap.put("avatarUrl", user.getAvatarUrl());
            coupleMap.put("partnerId", user.getCouplePartnerId());

            // 获取伴侣信息
            if (user.getCouplePartnerId() != null) {
                userRepository.findById(user.getCouplePartnerId()).ifPresent(partner -> {
                    coupleMap.put("partnerNickname", partner.getNickname());
                    coupleMap.put("partnerAvatarUrl", partner.getAvatarUrl());
                });
            }

            coupleMap.put("createdAt", user.getCreatedAt());
            couples.add(coupleMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", couples);
        result.put("totalElements", userPage.getTotalElements());
        result.put("totalPages", userPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    // 手机号脱敏
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7)
            return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }

    /**
     * 赠送/设置VIP
     */
    @PostMapping("/{id}/grant-vip")
    public ResponseEntity<Map<String, Object>> grantVip(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        String vipType = (String) request.get("vipType"); // MONTHLY, YEARLY, LIFETIME
        int days = getSafeInt(request.get("days"), 0);

        String reason = (String) request.get("reason"); // 操作原因

        User user = userOpt.get();
        user.setIsVip(true);
        user.setVipType(vipType);

        // 计算到期日期
        java.time.LocalDate expireDate;
        if ("LIFETIME".equals(vipType)) {
            expireDate = java.time.LocalDate.of(2099, 12, 31);
        } else if (days > 0) {
            expireDate = java.time.LocalDate.now().plusDays(days);
        } else if ("YEARLY".equals(vipType)) {
            expireDate = java.time.LocalDate.now().plusYears(1);
        } else {
            expireDate = java.time.LocalDate.now().plusMonths(1);
        }
        user.setVipExpireDate(expireDate);

        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "VIP赠送成功",
                "data", Map.of(
                        "userId", id,
                        "vipType", vipType,
                        "expireDate", expireDate.toString())));
    }

    /**
     * 延长VIP时间
     */
    @PostMapping("/{id}/extend-vip")
    public ResponseEntity<Map<String, Object>> extendVip(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        int days = getSafeInt(request.get("days"), 0);
        if (days <= 0) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "请指定延长天数"));
        }

        User user = userOpt.get();
        java.time.LocalDate currentExpire = user.getVipExpireDate();
        java.time.LocalDate baseDate = (currentExpire != null && currentExpire.isAfter(java.time.LocalDate.now()))
                ? currentExpire
                : java.time.LocalDate.now();
        java.time.LocalDate newExpire = baseDate.plusDays(days);

        user.setIsVip(true);
        user.setVipExpireDate(newExpire);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "VIP延长成功",
                "data", Map.of("newExpireDate", newExpire.toString())));
    }

    /**
     * 撤销VIP
     */
    @PostMapping("/{id}/revoke-vip")
    public ResponseEntity<Map<String, Object>> revokeVip(@PathVariable Long id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();
        user.setIsVip(false);
        user.setVipType(null);
        user.setVipExpireDate(null);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of("code", 0, "message", "VIP已撤销"));
    }

    /**
     * 禁用/启用用户
     */
    @PostMapping("/{id}/toggle-status")
    public ResponseEntity<Map<String, Object>> toggleUserStatus(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        Boolean disabled = (Boolean) request.get("disabled");
        String reason = (String) request.get("reason");

        User user = userOpt.get();
        user.setIsDisabled(disabled != null && disabled);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", disabled != null && disabled ? "用户已禁用" : "用户已启用"));
    }

    /**
     * 批量赠送VIP
     */
    @PostMapping("/batch-grant-vip")
    public ResponseEntity<Map<String, Object>> batchGrantVip(@RequestBody Map<String, Object> request) {
        @SuppressWarnings("unchecked")
        List<?> rawUserIds = (List<?>) request.get("userIds");
        String vipType = (String) request.get("vipType");
        int days = getSafeInt(request.get("days"), 0);

        if (rawUserIds == null || rawUserIds.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "请选择用户"));
        }

        // 安全转换userIds为Long类型（处理从JSON反序列化可能得到Integer的情况）
        List<Long> userIds = new java.util.ArrayList<>();
        for (Object id : rawUserIds) {
            if (id instanceof Number) {
                userIds.add(((Number) id).longValue());
            }
        }

        java.time.LocalDate expireDate;
        if ("LIFETIME".equals(vipType)) {
            expireDate = java.time.LocalDate.of(2099, 12, 31);
        } else if (days > 0) {
            expireDate = java.time.LocalDate.now().plusDays(days);
        } else if ("YEARLY".equals(vipType)) {
            expireDate = java.time.LocalDate.now().plusYears(1);
        } else {
            expireDate = java.time.LocalDate.now().plusMonths(1);
        }

        int successCount = 0;
        for (Long userId : userIds) {
            Optional<User> userOpt = userRepository.findById(userId);
            if (userOpt.isPresent()) {
                User user = userOpt.get();
                user.setIsVip(true);
                user.setVipType(vipType);
                user.setVipExpireDate(expireDate);
                userRepository.save(user);
                successCount++;
            }
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "批量赠送成功",
                "data", Map.of("successCount", successCount)));
    }

    // 辅助方法：安全获取整数参数
    private int getSafeInt(Object obj, int defaultValue) {
        if (obj == null)
            return defaultValue;
        if (obj instanceof Integer)
            return (Integer) obj;
        if (obj instanceof String) {
            try {
                return Integer.parseInt((String) obj);
            } catch (NumberFormatException e) {
                return defaultValue;
            }
        }
        if (obj instanceof Number)
            return ((Number) obj).intValue();
        return defaultValue;
    }

    /**
     * 恢复/赠送情侣VIP
     * 支持为单个用户或情侣双方恢复/赠送情侣会员
     * 同时也会恢复普通VIP状态
     */
    @PostMapping("/restore-couple-vip")
    public ResponseEntity<Map<String, Object>> restoreCoupleVip(@RequestBody Map<String, Object> request) {
        Long userId = ((Number) request.get("userId")).longValue();
        String vipType = (String) request.getOrDefault("vipType", "LIFETIME"); // LIFETIME, YEARLY, MONTHLY
        boolean applyToBoth = (Boolean) request.getOrDefault("applyToBoth", true); // 是否同时应用给情侣双方

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();

        // 情侣VIP永久有效
        java.time.LocalDate expireDate = java.time.LocalDate.of(2099, 12, 31);

        // 恢复当前用户的情侣VIP
        // 情侣VIP本质上是一种高级永久VIP，所以需要同时设置 isVip
        user.setIsCoupleVip(true);
        user.setCoupleVipType("LIFETIME");
        user.setCoupleVipExpireDate(expireDate);
        // 同时设置普通VIP状态，使用 COUPLE_LIFETIME 类型让APP正确识别
        user.setIsVip(true);
        user.setVipType("COUPLE_LIFETIME");
        user.setVipExpireDate(expireDate);
        userRepository.save(user);

        int affectedCount = 1;

        // 如果需要同时应用给情侣对象
        if (applyToBoth && user.getCouplePartnerId() != null) {
            Optional<User> partnerOpt = userRepository.findById(user.getCouplePartnerId());
            if (partnerOpt.isPresent()) {
                User partner = partnerOpt.get();
                partner.setIsCoupleVip(true);
                partner.setCoupleVipType("LIFETIME");
                partner.setCoupleVipExpireDate(expireDate);
                partner.setIsVip(true);
                partner.setVipType("COUPLE_LIFETIME");
                partner.setVipExpireDate(expireDate);
                userRepository.save(partner);
                affectedCount = 2;
            }
        }

        String typeLabel = "LIFETIME".equals(vipType) ? "永久" : ("YEARLY".equals(vipType) ? "年度" : "月度");
        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "情侣" + typeLabel + "会员恢复成功",
                "data", Map.of(
                        "affectedCount", affectedCount,
                        "expireDate", expireDate.toString())));
    }

    /**
     * 取消情侣VIP
     */
    @PostMapping("/cancel-couple-vip")
    public ResponseEntity<Map<String, Object>> cancelCoupleVip(@RequestBody Map<String, Object> request) {
        Long userId = ((Number) request.get("userId")).longValue();
        boolean applyToBoth = (Boolean) request.getOrDefault("applyToBoth", true);

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();
        user.setIsCoupleVip(false);
        user.setCoupleVipType(null);
        user.setCoupleVipExpireDate(null);
        userRepository.save(user);

        int affectedCount = 1;

        if (applyToBoth && user.getCouplePartnerId() != null) {
            Optional<User> partnerOpt = userRepository.findById(user.getCouplePartnerId());
            if (partnerOpt.isPresent()) {
                User partner = partnerOpt.get();
                partner.setIsCoupleVip(false);
                partner.setCoupleVipType(null);
                partner.setCoupleVipExpireDate(null);
                userRepository.save(partner);
                affectedCount = 2;
            }
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "情侣会员已取消",
                "data", Map.of("affectedCount", affectedCount)));
    }
}
