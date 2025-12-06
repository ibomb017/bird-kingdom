package com.birdkingdom.service;

import com.birdkingdom.dto.AuthDTO;
import com.birdkingdom.dto.UserDTO;
import com.birdkingdom.entity.User;
import com.birdkingdom.entity.VerificationCode;
import com.birdkingdom.repository.UserRepository;
import com.birdkingdom.repository.VerificationCodeRepository;
import com.birdkingdom.repository.UserFollowRepository;
import com.birdkingdom.repository.ForumPostRepository;
import com.birdkingdom.repository.BirdRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.Key;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.Random;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final VerificationCodeRepository verificationCodeRepository;
    private final UserFollowRepository userFollowRepository;
    private final ForumPostRepository forumPostRepository;
    private final BirdRepository birdRepository;
    private final AliyunSmsService aliyunSmsService;
    private final NeteaseSmsService neteaseSmsService;

    public AuthService(UserRepository userRepository, VerificationCodeRepository verificationCodeRepository,
                       UserFollowRepository userFollowRepository, ForumPostRepository forumPostRepository,
                       BirdRepository birdRepository, AliyunSmsService aliyunSmsService, 
                       NeteaseSmsService neteaseSmsService) {
        this.userRepository = userRepository;
        this.verificationCodeRepository = verificationCodeRepository;
        this.userFollowRepository = userFollowRepository;
        this.forumPostRepository = forumPostRepository;
        this.birdRepository = birdRepository;
        this.aliyunSmsService = aliyunSmsService;
        this.neteaseSmsService = neteaseSmsService;
    }
    
    // JWT密钥（生产环境应该从配置文件读取）
    private static final Key JWT_KEY = Keys.secretKeyFor(SignatureAlgorithm.HS256);
    private static final long JWT_EXPIRATION = 7 * 24 * 60 * 60 * 1000; // 7天
    
    /**
     * 发送验证码
     */
    @Transactional
    public AuthDTO.SendCodeResponse sendCode(String phone) {
        // 生成6位随机验证码
        String code = String.format("%06d", new Random().nextInt(1000000));
        
        // 保存验证码到数据库
        VerificationCode verificationCode = new VerificationCode();
        verificationCode.setPhone(phone);
        verificationCode.setCode(code);
        verificationCode.setExpireAt(LocalDateTime.now().plusMinutes(5)); // 5分钟有效
        verificationCodeRepository.save(verificationCode);
        
        // 优先使用网易云短信，失败则尝试阿里云
        boolean smsSent = neteaseSmsService.sendVerificationCode(phone, code);
        
        if (!smsSent) {
            // 网易云失败，尝试阿里云
            smsSent = aliyunSmsService.sendVerificationCode(phone, code);
        }
        
        if (!smsSent) {
            // 如果所有短信服务都失败，仍然打印到控制台（开发环境备用）
            System.out.println("⚠️ 短信发送失败，验证码 [" + phone + "]: " + code);
        }
        
        // 开发环境也打印到控制台，方便测试
        System.out.println("📱 验证码 [" + phone + "]: " + code);
        
        return new AuthDTO.SendCodeResponse(true, "验证码已发送");
    }
    
    /**
     * 登录/注册
     */
    @Transactional
    public AuthDTO.LoginResponse login(String phone, String code) {
        // 验证验证码
        VerificationCode verificationCode = verificationCodeRepository
            .findTopByPhoneAndUsedFalseOrderByCreatedAtDesc(phone)
            .orElse(null);
        
        if (verificationCode == null || !verificationCode.isValid() || !verificationCode.getCode().equals(code)) {
            // 开发模式：允许任意验证码
            if (!"123456".equals(code)) {
                return new AuthDTO.LoginResponse(false, "验证码错误或已过期", null, null);
            }
        } else {
            // 标记验证码已使用
            verificationCode.setUsed(true);
            verificationCodeRepository.save(verificationCode);
        }
        
        // 查找或创建用户
        User user = userRepository.findByPhone(phone).orElseGet(() -> {
            User newUser = new User();
            newUser.setPhone(phone);
            newUser.setNickname("鸟友" + phone.substring(phone.length() - 4));
            return userRepository.save(newUser);
        });
        
        // 生成JWT Token
        String token = generateToken(user.getId());
        
        // 转换为DTO
        UserDTO userDTO = convertToDTO(user);
        
        return new AuthDTO.LoginResponse(true, "登录成功", token, userDTO);
    }
    
    /**
     * 更新用户信息
     */
    @Transactional
    public UserDTO updateProfile(Long userId, AuthDTO.UpdateProfileRequest request) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        if (request.getNickname() != null) {
            user.setNickname(request.getNickname());
        }
        if (request.getBio() != null) {
            user.setBio(request.getBio());
        }
        if (request.getAvatarUrl() != null) {
            user.setAvatarUrl(request.getAvatarUrl());
        }
        
        userRepository.save(user);
        return convertToDTO(user);
    }
    
    /**
     * 获取用户信息
     */
    public UserDTO getUserById(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        return convertToDTO(user);
    }
    
    /**
     * 通过手机号搜索用户
     */
    public UserDTO searchByPhone(String phone) {
        return userRepository.findByPhone(phone)
            .map(this::convertToDTO)
            .orElse(null);
    }
    
    /**
     * 注销账号
     */
    @Transactional
    public void deleteAccount(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        // 删除用户相关的所有数据
        // 1. 删除用户的关注关系
        userFollowRepository.deleteByFollowerId(userId);
        userFollowRepository.deleteByFollowingId(userId);
        
        // 2. 删除用户的帖子（可选：根据业务需求决定是否保留）
        forumPostRepository.deleteByAuthorId(userId);
        
        // 3. 删除用户的鸟儿档案
        birdRepository.deleteByUserId(userId);
        
        // 4. 删除用户账号
        userRepository.delete(user);
    }
    
    /**
     * 生成JWT Token
     */
    private String generateToken(Long userId) {
        return Jwts.builder()
            .setSubject(userId.toString())
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + JWT_EXPIRATION))
            .signWith(JWT_KEY)
            .compact();
    }
    
    /**
     * 验证JWT Token
     */
    public Long validateToken(String token) {
        try {
            String subject = Jwts.parserBuilder()
                .setSigningKey(JWT_KEY)
                .build()
                .parseClaimsJws(token)
                .getBody()
                .getSubject();
            return Long.parseLong(subject);
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * 转换为DTO
     */
    private UserDTO convertToDTO(User user) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setPhone(user.getPhone());
        dto.setNickname(user.getNickname());
        dto.setAvatarUrl(user.getAvatarUrl());
        dto.setBio(user.getBio());
        dto.setIsVip(user.getIsVip());
        dto.setVipType(user.getVipType());
        dto.setVipExpireDate(user.getVipExpireDate());
        dto.setIsCoupleVip(user.getIsCoupleVip());
        dto.setCouplePartnerId(user.getCouplePartnerId());
        dto.setCreatedAt(user.getCreatedAt());
        
        // 统计数据
        dto.setBirdCount((int) birdRepository.count()); // 简化处理
        dto.setPostCount((int) forumPostRepository.findByAuthorIdOrderByCreatedAtDesc(user.getId(), null).getTotalElements());
        dto.setFollowerCount((int) userFollowRepository.countByFollowingId(user.getId()));
        dto.setFollowingCount((int) userFollowRepository.countByFollowerId(user.getId()));
        
        return dto;
    }
    
    /**
     * 验证旧手机号
     */
    @Transactional
    public AuthDTO.ChangePhoneResponse verifyOldPhone(Long userId, String oldCode) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        // 验证旧手机号的验证码
        VerificationCode verification = verificationCodeRepository
            .findTopByPhoneAndUsedFalseOrderByCreatedAtDesc(user.getPhone())
            .orElseThrow(() -> new RuntimeException("验证码无效或已使用"));
        
        // 检查验证码是否匹配
        if (!verification.getCode().equals(oldCode)) {
            throw new RuntimeException("验证码错误");
        }
        
        // 检查验证码是否过期
        if (!verification.isValid()) {
            throw new RuntimeException("验证码已过期");
        }
        
        // 标记验证码为已使用
        verification.setUsed(true);
        verificationCodeRepository.save(verification);
        
        return new AuthDTO.ChangePhoneResponse(true, "旧手机号验证成功");
    }
    
    /**
     * 修改手机号
     */
    @Transactional
    public AuthDTO.ChangePhoneResponse changePhone(Long userId, String newPhone, String code) {
        // 验证验证码
        VerificationCode verificationCode = verificationCodeRepository
            .findTopByPhoneAndUsedFalseOrderByCreatedAtDesc(newPhone)
            .orElse(null);
        
        if (verificationCode == null || !verificationCode.isValid() || !verificationCode.getCode().equals(code)) {
            // 开发模式：允许任意验证码
            if (!"123456".equals(code)) {
                return new AuthDTO.ChangePhoneResponse(false, "验证码错误或已过期");
            }
        } else {
            // 标记验证码已使用
            verificationCode.setUsed(true);
            verificationCodeRepository.save(verificationCode);
        }
        
        // 检查新手机号是否已被使用
        if (userRepository.findByPhone(newPhone).isPresent()) {
            return new AuthDTO.ChangePhoneResponse(false, "该手机号已被其他用户使用");
        }
        
        // 更新手机号
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        user.setPhone(newPhone);
        userRepository.save(user);
        
        return new AuthDTO.ChangePhoneResponse(true, "手机号修改成功");
    }
    
    /**
     * 设置密码
     */
    @Transactional
    public void setPassword(Long userId, String password) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        // TODO: 实际应该加密密码
        // String hashedPassword = passwordEncoder.encode(password);
        user.setPassword(password); // 简化处理，实际应该加密
        userRepository.save(user);
    }
    
    /**
     * 密码登录
     */
    @Transactional
    public AuthDTO.LoginResponse loginWithPassword(String phone, String password) {
        User user = userRepository.findByPhone(phone)
            .orElse(null);
        
        if (user == null) {
            return new AuthDTO.LoginResponse(false, "手机号未注册", null, null);
        }
        
        // TODO: 实际应该验证加密后的密码
        // if (!passwordEncoder.matches(password, user.getPassword())) {
        if (user.getPassword() == null || !user.getPassword().equals(password)) {
            return new AuthDTO.LoginResponse(false, "密码错误", null, null);
        }
        
        // 生成JWT Token
        String token = generateToken(user.getId());
        
        UserDTO userDTO = convertToDTO(user);
        return new AuthDTO.LoginResponse(true, "登录成功", token, userDTO);
    }
    
    /**
     * 购买/续费VIP
     */
    @Transactional
    public AuthDTO.VipPurchaseResponse purchaseVip(Long userId, String vipType, Integer duration) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime newExpireDate;
        
        if ("COUPLE_LIFETIME".equals(vipType)) {
            // 情侣永久会员：设置为100年后
            newExpireDate = now.plusYears(100);
            user.setVipType("COUPLE_LIFETIME");
            user.setIsCoupleVip(true);
        } else if ("LIFETIME".equals(vipType)) {
            // 永久会员：设置为100年后
            newExpireDate = now.plusYears(100);
            user.setVipType("LIFETIME");
        } else {
            // 计算新的过期时间
            LocalDateTime baseDate;
            
            // 如果已经是VIP且未过期，从当前过期时间开始叠加
            if (user.getIsVip() && user.getVipExpireDate() != null && user.getVipExpireDate().isAfter(now)) {
                baseDate = user.getVipExpireDate();
            } else {
                // 否则从现在开始计算
                baseDate = now;
            }
            
            // 根据类型计算时长
            int months = duration != null ? duration : ("YEARLY".equals(vipType) ? 12 : 1);
            newExpireDate = baseDate.plusMonths(months);
            user.setVipType(vipType);
        }
        
        user.setIsVip(true);
        user.setVipExpireDate(newExpireDate);
        userRepository.save(user);
        
        // 计算剩余天数
        int remainingDays = (int) java.time.temporal.ChronoUnit.DAYS.between(now, newExpireDate);
        
        String message = "LIFETIME".equals(vipType) ? "已开通永久会员" : 
                        String.format("已续费%d个月，剩余%d天", duration != null ? duration : 1, remainingDays);
        
        return new AuthDTO.VipPurchaseResponse(
            true,
            message,
            user.getVipType(),
            newExpireDate.toString(),
            remainingDays
        );
    }
    
    /**
     * 绑定情侣伴侣
     */
    @Transactional
    public java.util.Map<String, Object> bindCouplePartner(Long userId, String partnerPhone) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        // 检查是否是情侣会员
        if (!Boolean.TRUE.equals(user.getIsCoupleVip())) {
            throw new RuntimeException("需要先开通情侣会员");
        }
        
        // 查找伴侣
        User partner = userRepository.findByPhone(partnerPhone)
            .orElseThrow(() -> new RuntimeException("伴侣用户不存在"));
        
        // 检查伴侣是否也是情侣会员
        if (!Boolean.TRUE.equals(partner.getIsCoupleVip())) {
            throw new RuntimeException("伴侣需要先开通情侣会员");
        }
        
        // 检查是否已经绑定
        if (user.getCouplePartnerId() != null) {
            throw new RuntimeException("您已经绑定了情侣伴侣");
        }
        
        if (partner.getCouplePartnerId() != null) {
            throw new RuntimeException("对方已经绑定了其他伴侣");
        }
        
        // 双向绑定
        user.setCouplePartnerId(partner.getId());
        partner.setCouplePartnerId(user.getId());
        
        userRepository.save(user);
        userRepository.save(partner);
        
        java.util.Map<String, Object> result = new java.util.HashMap<>();
        result.put("success", true);
        result.put("message", "绑定成功");
        result.put("partnerName", partner.getNickname());
        
        return result;
    }
    
    /**
     * 解绑情侣伴侣
     * 解绑后双方都降级为普通永久会员，情侣标识永久失效
     */
    @Transactional
    public void unbindCouplePartner(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        if (user.getCouplePartnerId() == null) {
            throw new RuntimeException("您还没有绑定情侣伴侣");
        }
        
        // 解除双向绑定并降级为普通永久会员
        Long partnerId = user.getCouplePartnerId();
        
        // 当前用户降级
        user.setCouplePartnerId(null);
        user.setIsCoupleVip(false);
        if ("COUPLE_LIFETIME".equals(user.getVipType())) {
            user.setVipType("LIFETIME"); // 降级为普通永久会员
        }
        userRepository.save(user);
        
        // 伴侣也降级
        userRepository.findById(partnerId).ifPresent(partner -> {
            partner.setCouplePartnerId(null);
            partner.setIsCoupleVip(false);
            if ("COUPLE_LIFETIME".equals(partner.getVipType())) {
                partner.setVipType("LIFETIME"); // 降级为普通永久会员
            }
            userRepository.save(partner);
        });
    }
}
