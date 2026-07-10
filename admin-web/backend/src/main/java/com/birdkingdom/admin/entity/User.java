package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 用户实体 (对接主库 users 表，支持读写)
 */
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 20)
    private String phone;

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
    private LocalDate vipExpireDate;

    @Column(name = "is_couple_vip")
    private Boolean isCoupleVip = false;

    @Column(name = "couple_vip_type", length = 20)
    private String coupleVipType;

    @Column(name = "couple_vip_expire_date")
    private LocalDate coupleVipExpireDate;

    @Column(name = "couple_partner_id")
    private Long couplePartnerId;

    @Column(name = "is_disabled")
    private Boolean isDisabled = false;

    @Column(name = "role", length = 20)
    private String role = "USER";

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Getters
    public Long getId() {
        return id;
    }

    public String getPhone() {
        return phone;
    }

    public String getNickname() {
        return nickname;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public String getBio() {
        return bio;
    }

    public Boolean getIsVip() {
        return isVip;
    }

    public String getVipType() {
        return vipType;
    }

    public LocalDate getVipExpireDate() {
        return vipExpireDate;
    }

    public Boolean getIsCoupleVip() {
        return isCoupleVip;
    }

    public Long getCouplePartnerId() {
        return couplePartnerId;
    }

    public Boolean getIsDisabled() {
        return isDisabled;
    }

    public String getRole() {
        return role;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    // Setters for VIP management
    public void setIsVip(Boolean isVip) {
        this.isVip = isVip;
    }

    public void setVipType(String vipType) {
        this.vipType = vipType;
    }

    public void setVipExpireDate(LocalDate vipExpireDate) {
        this.vipExpireDate = vipExpireDate;
    }

    public void setIsDisabled(Boolean isDisabled) {
        this.isDisabled = isDisabled;
    }

    public void setIsCoupleVip(Boolean isCoupleVip) {
        this.isCoupleVip = isCoupleVip;
    }

    public void setCouplePartnerId(Long couplePartnerId) {
        this.couplePartnerId = couplePartnerId;
    }

    public String getCoupleVipType() {
        return coupleVipType;
    }

    public void setCoupleVipType(String coupleVipType) {
        this.coupleVipType = coupleVipType;
    }

    public LocalDate getCoupleVipExpireDate() {
        return coupleVipExpireDate;
    }

    public void setCoupleVipExpireDate(LocalDate coupleVipExpireDate) {
        this.coupleVipExpireDate = coupleVipExpireDate;
    }

    // Additional setters for editing
    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public void setBio(String bio) {
        this.bio = bio;
    }
}
