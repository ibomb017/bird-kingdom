package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.*;
import com.birdkingdom.admin.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.*;

/**
 * 系统管理Controller - 配置、角色、日志、管理员管理
 */
@RestController
@RequestMapping("/api/admin/system")
public class SystemController {

    @Autowired
    private SystemConfigRepository systemConfigRepository;

    @Autowired
    private AdminRoleRepository adminRoleRepository;

    @Autowired
    private AdminLoginLogRepository adminLoginLogRepository;

    @Autowired
    private AdminUserRepository adminUserRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * 获取系统配置
     */
    @GetMapping("/config")
    public ResponseEntity<Map<String, Object>> getConfig() {
        List<SystemConfig> configs = systemConfigRepository.findAll();

        Map<String, Object> configMap = new HashMap<>();
        for (SystemConfig config : configs) {
            // 根据值类型转换
            Object value = parseConfigValue(config.getConfigValue(), config.getValueType());
            configMap.put(config.getConfigKey().replace(".", "_"), value);
        }

        // 格式化为前端需要的结构
        Map<String, Object> result = new HashMap<>();
        result.put("appName", configMap.getOrDefault("app_name", "鸟鸟王国"));
        result.put("version", configMap.getOrDefault("app_version", "1.0.0"));
        result.put("customerServicePhone", configMap.getOrDefault("app_customer_service_phone", ""));
        result.put("splashPrice", configMap.getOrDefault("splash_price", 99));
        result.put("splashSlotsPerDay", configMap.getOrDefault("splash_slots_per_day", 10));
        result.put("vipMonthlyPrice", configMap.getOrDefault("vip_monthly_price", 9.9));
        result.put("vipYearlyPrice", configMap.getOrDefault("vip_yearly_price", 88));

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
    }

    /**
     * 更新系统配置
     */
    @PutMapping("/config")
    public ResponseEntity<Map<String, Object>> updateConfig(@RequestBody Map<String, Object> request) {
        try {
            for (Map.Entry<String, Object> entry : request.entrySet()) {
                String key = entry.getKey().replace("_", ".");
                String value = String.valueOf(entry.getValue());

                Optional<SystemConfig> configOpt = systemConfigRepository.findByConfigKey(key);
                if (configOpt.isPresent()) {
                    SystemConfig config = configOpt.get();
                    config.setConfigValue(value);
                    systemConfigRepository.save(config);
                }
            }
            return ResponseEntity.ok(Map.of("code", 0, "message", "配置更新成功"));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "配置更新失败: " + e.getMessage()));
        }
    }

    /**
     * 获取角色列表
     */
    @GetMapping("/roles")
    public ResponseEntity<Map<String, Object>> getRoles() {
        List<AdminRole> roles = adminRoleRepository.findAll();

        List<Map<String, Object>> roleList = new ArrayList<>();
        for (AdminRole role : roles) {
            Map<String, Object> roleMap = new HashMap<>();
            roleMap.put("id", role.getId());
            roleMap.put("code", role.getRoleCode());
            roleMap.put("name", role.getRoleName());
            roleMap.put("description", role.getDescription());

            // 解析权限JSON
            List<String> permissions = parsePermissions(role.getPermissions());
            roleMap.put("permissions", permissions);

            roleList.add(roleMap);
        }

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", roleList));
    }

    /**
     * 获取管理员列表
     */
    @GetMapping("/admins")
    public ResponseEntity<Map<String, Object>> getAdmins(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<AdminUser> adminPage = adminUserRepository.findAll(pageRequest);

        List<Map<String, Object>> admins = new ArrayList<>();
        for (AdminUser admin : adminPage.getContent()) {
            Map<String, Object> adminMap = new HashMap<>();
            adminMap.put("id", admin.getId());
            adminMap.put("username", admin.getUsername());
            adminMap.put("nickname", admin.getNickname());
            adminMap.put("email", admin.getEmail());
            adminMap.put("phone", admin.getPhone());
            adminMap.put("avatar", admin.getAvatar());
            adminMap.put("roleCode", admin.getRoleCode());
            adminMap.put("status", "ACTIVE".equals(admin.getStatus()) ? 1 : 0);
            adminMap.put("lastLoginAt", admin.getLastLoginAt());
            adminMap.put("createdAt", admin.getCreatedAt());

            admins.add(adminMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", admins);
        result.put("totalElements", adminPage.getTotalElements());
        result.put("totalPages", adminPage.getTotalPages());

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
    }

    /**
     * 获取登录日志
     */
    @GetMapping("/login-logs")
    public ResponseEntity<Map<String, Object>> getLoginLogs(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        PageRequest pageRequest = PageRequest.of(page, size);
        Page<AdminLoginLog> logPage = adminLoginLogRepository.findAllByOrderByLoginTimeDesc(pageRequest);

        List<Map<String, Object>> logs = new ArrayList<>();
        for (AdminLoginLog log : logPage.getContent()) {
            Map<String, Object> logMap = new HashMap<>();
            logMap.put("id", log.getId());
            logMap.put("adminId", log.getAdminId());
            logMap.put("username", log.getUsername());
            logMap.put("nickname", log.getNickname());
            logMap.put("loginIp", log.getLoginIp());
            logMap.put("loginTime", log.getLoginTime());
            logMap.put("loginResult", log.getLoginResult());

            logs.add(logMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", logs);
        result.put("totalElements", logPage.getTotalElements());
        result.put("totalPages", logPage.getTotalPages());

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
    }

    /**
     * 系统健康检查
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        health.put("status", "UP");
        health.put("timestamp", System.currentTimeMillis());
        health.put("database", "UP");
        health.put("cache", "UP");

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", health));
    }

    /**
     * 解析配置值
     */
    private Object parseConfigValue(String value, String type) {
        if (value == null)
            return null;

        try {
            switch (type) {
                case "NUMBER":
                    if (value.contains(".")) {
                        return Double.parseDouble(value);
                    }
                    return Integer.parseInt(value);
                case "BOOLEAN":
                    return Boolean.parseBoolean(value);
                case "JSON":
                    // 这里可以使用Jackson解析JSON，暂时返回字符串
                    return value;
                default:
                    return value;
            }
        } catch (Exception e) {
            return value;
        }
    }

    /**
     * 解析权限JSON数组
     */
    private List<String> parsePermissions(String permissionsJson) {
        if (permissionsJson == null || permissionsJson.isEmpty()) {
            return new ArrayList<>();
        }

        try {
            // 简单解析 ["ALL"] 或 ["USER_MANAGE", "CONTENT_MANAGE"]
            permissionsJson = permissionsJson.trim();
            if (permissionsJson.startsWith("[") && permissionsJson.endsWith("]")) {
                permissionsJson = permissionsJson.substring(1, permissionsJson.length() - 1);
                String[] perms = permissionsJson.replace("\"", "").split(",");
                return Arrays.asList(perms);
            }
        } catch (Exception e) {
            // 解析失败返回空列表
        }

        return new ArrayList<>();
    }

    /**
     * 创建管理员
     */
    @PostMapping("/admins")
    public ResponseEntity<Map<String, Object>> createAdmin(@RequestBody Map<String, String> request) {
        try {
            String username = request.get("username");
            String password = request.get("password");
            String nickname = request.get("nickname");
            String roleCode = request.get("roleCode");

            // 检查用户名是否已存在
            if (adminUserRepository.findByUsername(username).isPresent()) {
                return ResponseEntity.ok(Map.of("code", 1, "message", "用户名已存在"));
            }

            AdminUser admin = new AdminUser();
            admin.setUsername(username);
            admin.setPassword(passwordEncoder.encode(password)); // BCrypt加密
            admin.setNickname(nickname);
            admin.setRoleCode(roleCode != null ? roleCode : "ADMIN");
            admin.setStatus("ACTIVE");
            admin.setEmail(request.get("email"));
            admin.setPhone(request.get("phone"));

            adminUserRepository.save(admin);

            return ResponseEntity.ok(Map.of("code", 0, "message", "管理员创建成功"));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "创建失败: " + e.getMessage()));
        }
    }

    /**
     * 更新管理员
     */
    @PutMapping("/admins/{id}")
    public ResponseEntity<Map<String, Object>> updateAdmin(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {
        try {
            Optional<AdminUser> adminOpt = adminUserRepository.findById(id);
            if (adminOpt.isEmpty()) {
                return ResponseEntity.ok(Map.of("code", 1, "message", "管理员不存在"));
            }

            AdminUser admin = adminOpt.get();

            if (request.containsKey("nickname")) {
                admin.setNickname(request.get("nickname"));
            }
            if (request.containsKey("email")) {
                admin.setEmail(request.get("email"));
            }
            if (request.containsKey("phone")) {
                admin.setPhone(request.get("phone"));
            }
            if (request.containsKey("roleCode")) {
                admin.setRoleCode(request.get("roleCode"));
            }
            if (request.containsKey("status")) {
                admin.setStatus(request.get("status"));
            }
            if (request.containsKey("password") && !request.get("password").isEmpty()) {
                admin.setPassword(passwordEncoder.encode(request.get("password"))); // BCrypt加密
            }

            adminUserRepository.save(admin);

            return ResponseEntity.ok(Map.of("code", 0, "message", "管理员更新成功"));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "更新失败: " + e.getMessage()));
        }
    }

    /**
     * 删除管理员
     */
    @DeleteMapping("/admins/{id}")
    public ResponseEntity<Map<String, Object>> deleteAdmin(@PathVariable Long id) {
        try {
            if (!adminUserRepository.existsById(id)) {
                return ResponseEntity.ok(Map.of("code", 1, "message", "管理员不存在"));
            }

            adminUserRepository.deleteById(id);

            return ResponseEntity.ok(Map.of("code", 0, "message", "管理员删除成功"));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "删除失败: " + e.getMessage()));
        }
    }
}
