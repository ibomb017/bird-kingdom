package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.User;
import com.birdkingdom.admin.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 用户管理扩展Controller - 补充CRUD功能
 */
@RestController
@RequestMapping("/api/admin/users")
public class UserExtController {

    @Autowired
    private UserRepository userRepository;

    /**
     * 更新用户信息
     */
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> updateUser(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();
        if (request.containsKey("nickname")) {
            user.setNickname((String) request.get("nickname"));
        }
        if (request.containsKey("bio")) {
            user.setBio((String) request.get("bio"));
        }
        userRepository.save(user);

        return ResponseEntity.ok(Map.of("code", 0, "message", "用户信息更新成功"));
    }

    /**
     * 删除用户（软删除）
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteUser(@PathVariable Long id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();
        user.setIsDisabled(true);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of("code", 0, "message", "用户已删除"));
    }

    /**
     * 解绑情侣关系
     */
    @PostMapping("/couples/{id}/unbind")
    public ResponseEntity<Map<String, Object>> unbindCouple(@PathVariable Long id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "用户不存在"));
        }

        User user = userOpt.get();
        Long partnerId = user.getCouplePartnerId();
        if (partnerId == null) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "该用户未绑定情侣"));
        }

        // 解绑双方
        user.setCouplePartnerId(null);
        user.setIsCoupleVip(false);
        userRepository.save(user);

        userRepository.findById(partnerId).ifPresent(partner -> {
            partner.setCouplePartnerId(null);
            partner.setIsCoupleVip(false);
            userRepository.save(partner);
        });

        return ResponseEntity.ok(Map.of("code", 0, "message", "情侣关系已解绑"));
    }

    /**
     * 用户统计数据
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getUserStatistics() {
        long totalUsers = userRepository.count();
        long vipUsers = userRepository.countByIsVipTrue();
        long coupleUsers = userRepository.countByCouplePartnerIdNotNull();

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", totalUsers);
        stats.put("vipUsers", vipUsers);
        stats.put("coupleUsers", coupleUsers);
        stats.put("vipRate", totalUsers > 0 ? String.format("%.2f%%", vipUsers * 100.0 / totalUsers) : "0%");

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", stats));
    }
}
