package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.service.AdminAuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 管理员认证控制器
 */
@RestController
@RequestMapping("/api/admin/auth")
public class AuthController {

    @Autowired
    private AdminAuthService adminAuthService;

    /**
     * 登录
     * POST /api/admin/auth/login
     */
    @PostMapping("/login")
    public ResponseEntity<Map<String, Object>> login(@RequestBody Map<String, String> request) {
        String username = request.get("username");
        String password = request.get("password");

        if (username == null || password == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 1,
                    "message", "用户名和密码不能为空"));
        }

        Map<String, Object> result = adminAuthService.login(username, password);

        if (result.containsKey("error")) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 1,
                    "message", result.get("error").toString()));
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "登录成功",
                "data", result));
    }

    /**
     * 登出
     * POST /api/admin/auth/logout
     */
    @PostMapping("/logout")
    public ResponseEntity<Map<String, Object>> logout() {
        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "登出成功"));
    }

    /**
     * 获取当前管理员信息
     * GET /api/admin/auth/me
     */
    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> getCurrentAdmin(
            @RequestHeader(value = "Authorization", required = false) String token) {
        Map<String, Object> adminInfo = adminAuthService.getAdminByToken(token);

        if (adminInfo == null) {
            return ResponseEntity.status(401).body(Map.of(
                    "code", 401,
                    "message", "未授权"));
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", adminInfo));
    }

    /**
     * 修改密码
     * POST /api/admin/auth/change-password
     */
    @PostMapping("/change-password")
    public ResponseEntity<Map<String, Object>> changePassword(
            @RequestHeader(value = "Authorization", required = false) String token,
            @RequestBody Map<String, String> request) {
        String oldPassword = request.get("oldPassword");
        String newPassword = request.get("newPassword");

        if (oldPassword == null || newPassword == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 1,
                    "message", "旧密码和新密码不能为空"));
        }

        if (newPassword.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 1,
                    "message", "新密码长度不能少于6位"));
        }

        Map<String, Object> result = adminAuthService.changePassword(token, oldPassword, newPassword);
        if (result.containsKey("error")) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 1,
                    "message", result.get("error").toString()));
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "密码修改成功"));
    }
}
