package com.birdkingdom.admin.service;

import com.birdkingdom.admin.config.JwtUtil;
import com.birdkingdom.admin.entity.AdminUser;
import com.birdkingdom.admin.repository.AdminUserRepository;
import com.birdkingdom.admin.entity.User;
import com.birdkingdom.admin.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * 管理员认证服务
 */
@Service
public class AdminAuthService {

    @Autowired
    private AdminUserRepository adminUserRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    // 默认管理员账号密码
    private static final String DEFAULT_USERNAME = "admin";
    private static final String DEFAULT_PASSWORD = "123456";

    /**
     * 初始化默认管理员
     */
    @PostConstruct
    public void initDefaultAdmin() {
        if (!adminUserRepository.existsByUsername(DEFAULT_USERNAME)) {
            AdminUser admin = new AdminUser();
            admin.setUsername(DEFAULT_USERNAME);
            admin.setPassword(passwordEncoder.encode(DEFAULT_PASSWORD));
            admin.setNickname("超级管理员");
            admin.setRoleCode("SUPER_ADMIN");
            admin.setStatus("ACTIVE");
            adminUserRepository.save(admin);
            System.out.println("✅ 默认管理员账号已创建: admin / 123456");
        }
    }

    /**
     * 登录
     */
    public Map<String, Object> login(String username, String password) {
        Map<String, Object> result = new HashMap<>();

        Optional<AdminUser> adminOpt = adminUserRepository.findByUsername(username);

        if (adminOpt.isEmpty()) {
            result.put("error", "用户名或密码错误");
            return result;
        }

        AdminUser admin = adminOpt.get();

        // 检查状态
        if (!"ACTIVE".equals(admin.getStatus())) {
            result.put("error", "账号已被禁用");
            return result;
        }

        // 验证密码
        if (!passwordEncoder.matches(password, admin.getPassword())) {
            admin.setLoginFailCount(admin.getLoginFailCount() + 1);
            adminUserRepository.save(admin);
            result.put("error", "用户名或密码错误");
            return result;
        }

        // 登录成功，更新信息
        admin.setLastLoginAt(LocalDateTime.now());
        admin.setLoginFailCount(0);
        adminUserRepository.save(admin);

        // 生成 token
        String token = jwtUtil.generateToken(admin.getId(), admin.getUsername());

        // 构建用户信息
        Map<String, Object> user = new HashMap<>();
        user.put("id", admin.getId());
        user.put("username", admin.getUsername());
        user.put("nickname", admin.getNickname());
        user.put("avatar", admin.getAvatar());
        user.put("role", admin.getRoleCode());

        result.put("token", token);
        result.put("user", user);

        return result;
    }

    /**
     * 根据 token 获取管理员信息
     */
    public Map<String, Object> getAdminByToken(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return null;
        }

        String token = authHeader.substring(7);
        Long adminId = jwtUtil.getAdminIdFromToken(token);

        if (adminId == null) {
            return null;
        }

        Optional<AdminUser> adminOpt = adminUserRepository.findById(adminId);
        if (adminOpt.isPresent()) {
            AdminUser admin = adminOpt.get();
            Map<String, Object> user = new HashMap<>();
            user.put("id", admin.getId());
            user.put("username", admin.getUsername());
            user.put("nickname", admin.getNickname());
            user.put("avatar", admin.getAvatar());
            user.put("role", admin.getRoleCode());
            return user;
        }

        // Fallback to app users table for Swift admin users
        Optional<User> appUserOpt = userRepository.findById(adminId);
        if (appUserOpt.isPresent()) {
            User appUser = appUserOpt.get();
            if ("ADMIN".equalsIgnoreCase(appUser.getRole())) {
                Map<String, Object> user = new HashMap<>();
                user.put("id", appUser.getId());
                user.put("username", appUser.getPhone());
                user.put("nickname", appUser.getNickname());
                user.put("avatar", appUser.getAvatarUrl());
                user.put("role", "ADMIN");
                return user;
            }
        }

        return null;
    }

    /**
     * 修改密码
     */
    public Map<String, Object> changePassword(String authHeader, String oldPassword, String newPassword) {
        Map<String, Object> result = new HashMap<>();

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            result.put("error", "未授权");
            return result;
        }

        String token = authHeader.substring(7);
        Long adminId = jwtUtil.getAdminIdFromToken(token);

        if (adminId == null) {
            result.put("error", "无效的令牌");
            return result;
        }

        Optional<AdminUser> adminOpt = adminUserRepository.findById(adminId);
        if (adminOpt.isEmpty()) {
            result.put("error", "用户不存在");
            return result;
        }

        AdminUser admin = adminOpt.get();

        // 验证旧密码
        if (!passwordEncoder.matches(oldPassword, admin.getPassword())) {
            result.put("error", "当前密码错误");
            return result;
        }

        // 更新密码
        admin.setPassword(passwordEncoder.encode(newPassword));
        adminUserRepository.save(admin);

        result.put("success", true);
        return result;
    }
}
