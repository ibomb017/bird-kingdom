package com.birdkingdom.controller;

import com.birdkingdom.dto.AuthDTO;
import com.birdkingdom.dto.UserDTO;
import com.birdkingdom.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }
    
    /**
     * 发送验证码
     */
    @PostMapping("/send-code")
    public ResponseEntity<AuthDTO.SendCodeResponse> sendCode(@RequestBody AuthDTO.SendCodeRequest request) {
        return ResponseEntity.ok(authService.sendCode(request.getPhone()));
    }
    
    /**
     * 登录/注册
     */
    @PostMapping("/login")
    public ResponseEntity<AuthDTO.LoginResponse> login(@RequestBody AuthDTO.LoginRequest request) {
        return ResponseEntity.ok(authService.login(request.getPhone(), request.getCode()));
    }
    
    /**
     * 获取当前用户信息
     */
    @GetMapping("/me")
    public ResponseEntity<UserDTO> getCurrentUser(@RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(authService.getUserById(userId));
    }
    
    /**
     * 更新用户信息
     */
    @PutMapping("/profile")
    public ResponseEntity<UserDTO> updateProfile(
            @RequestHeader("Authorization") String authorization,
            @RequestBody AuthDTO.UpdateProfileRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(authService.updateProfile(userId, request));
    }
    
    /**
     * 验证Token
     */
    @GetMapping("/validate")
    public ResponseEntity<Void> validateToken(@RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok().build();
    }
    
    /**
     * 搜索用户（通过手机号）
     */
    @GetMapping("/users/search/{phone}")
    public ResponseEntity<?> searchUser(@PathVariable String phone) {
        UserDTO user = authService.searchByPhone(phone);
        if (user != null) {
            return ResponseEntity.ok(new SearchUserResponse(true, user));
        }
        return ResponseEntity.ok(new SearchUserResponse(false, null));
    }
    
    /**
     * 注销账号
     */
    @DeleteMapping("/delete-account")
    public ResponseEntity<Void> deleteAccount(@RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        authService.deleteAccount(userId);
        return ResponseEntity.ok().build();
    }
    
    /**
     * 修改手机号 - 步骤1：验证旧手机号
     */
    @PostMapping("/change-phone/verify-old")
    public ResponseEntity<AuthDTO.ChangePhoneResponse> verifyOldPhone(
            @RequestHeader("Authorization") String authorization,
            @RequestBody AuthDTO.VerifyOldPhoneRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(authService.verifyOldPhone(userId, request.getOldCode()));
    }
    
    /**
     * 修改手机号 - 步骤2：发送验证码到新手机
     */
    @PostMapping("/change-phone/send-code")
    public ResponseEntity<AuthDTO.SendCodeResponse> sendCodeForChangePhone(
            @RequestHeader("Authorization") String authorization,
            @RequestBody AuthDTO.ChangePhoneRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(authService.sendCode(request.getNewPhone()));
    }
    
    /**
     * 修改手机号 - 步骤3：验证新手机号并更新
     */
    @PostMapping("/change-phone")
    public ResponseEntity<AuthDTO.ChangePhoneResponse> changePhone(
            @RequestHeader("Authorization") String authorization,
            @RequestBody AuthDTO.ChangePhoneRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(authService.changePhone(userId, request.getNewPhone(), request.getNewCode()));
    }
    
    /**
     * 设置密码
     */
    @PostMapping("/set-password")
    public ResponseEntity<Void> setPassword(
            @RequestHeader("Authorization") String authorization,
            @RequestBody AuthDTO.SetPasswordRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        authService.setPassword(userId, request.getPassword());
        return ResponseEntity.ok().build();
    }
    
    /**
     * 密码登录
     */
    @PostMapping("/login-password")
    public ResponseEntity<AuthDTO.LoginResponse> loginWithPassword(@RequestBody AuthDTO.PasswordLoginRequest request) {
        return ResponseEntity.ok(authService.loginWithPassword(request.getPhone(), request.getPassword()));
    }
    
    /**
     * 购买/续费VIP
     */
    @PostMapping("/vip/purchase")
    public ResponseEntity<AuthDTO.VipPurchaseResponse> purchaseVip(
            @RequestHeader("Authorization") String authorization,
            @RequestBody AuthDTO.VipPurchaseRequest request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(authService.purchaseVip(userId, request.getVipType(), request.getDuration()));
    }
    
    /**
     * 绑定情侣伴侣
     */
    @PostMapping("/couple/bind")
    public ResponseEntity<Map<String, Object>> bindCouplePartner(
            @RequestHeader("Authorization") String authorization,
            @RequestBody Map<String, String> request) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        String partnerPhone = request.get("partnerPhone");
        return ResponseEntity.ok(authService.bindCouplePartner(userId, partnerPhone));
    }
    
    /**
     * 解绑情侣伴侣
     */
    @PostMapping("/couple/unbind")
    public ResponseEntity<Void> unbindCouplePartner(@RequestHeader("Authorization") String authorization) {
        Long userId = extractUserId(authorization);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        authService.unbindCouplePartner(userId);
        return ResponseEntity.ok().build();
    }
    
    /**
     * 从Authorization头提取用户ID
     */
    private Long extractUserId(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            return null;
        }
        String token = authorization.substring(7);
        return authService.validateToken(token);
    }
    
    // 内部类
    record SearchUserResponse(boolean found, UserDTO user) {}
}
