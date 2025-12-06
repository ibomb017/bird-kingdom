package com.birdkingdom.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 用户实体
 */
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 20)
    private String phone;
    
    @Column(length = 255)
    private String password;

    @Column(nullable = false, length = 50)
    private String nickname;

    @Column(name = "avatar_url", length = 255)
    private String avatarUrl;

    @Column(length = 500)
    private String bio;

    @Column(name = "is_vip")
    private Boolean isVip = false;

    @Column(name = "vip_type", length = 20)
    private String vipType;

    @Column(name = "vip_expire_date")
    private LocalDateTime vipExpireDate;
    
    @Column(name = "is_couple_vip")
    private Boolean isCoupleVip = false;
    
    @Column(name = "couple_partner_id")
    private Long couplePartnerId; // 情侣伴侣的用户ID

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public User() {}

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getBio() { return bio; }
    public void setBio(String bio) { this.bio = bio; }

    public Boolean getIsVip() { return isVip; }
    public void setIsVip(Boolean isVip) { this.isVip = isVip; }

    public String getVipType() { return vipType; }
    public void setVipType(String vipType) { this.vipType = vipType; }

    public LocalDateTime getVipExpireDate() { return vipExpireDate; }
    public void setVipExpireDate(LocalDateTime vipExpireDate) { this.vipExpireDate = vipExpireDate; }
    
    public Boolean getIsCoupleVip() { return isCoupleVip; }
    public void setIsCoupleVip(Boolean isCoupleVip) { this.isCoupleVip = isCoupleVip; }
    
    public Long getCouplePartnerId() { return couplePartnerId; }
    public void setCouplePartnerId(Long couplePartnerId) { this.couplePartnerId = couplePartnerId; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (isVip == null) isVip = false;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
