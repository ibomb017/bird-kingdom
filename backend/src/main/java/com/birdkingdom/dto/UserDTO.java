package com.birdkingdom.dto;

import java.time.LocalDateTime;

public class UserDTO {
    private Long id;
    private String phone;
    private String nickname;
    private String avatarUrl;
    private String bio;
    private Boolean isVip;
    private String vipType;
    private LocalDateTime vipExpireDate;
    private Boolean isCoupleVip;
    private Long couplePartnerId;
    private LocalDateTime createdAt;
    private Integer birdCount;
    private Integer postCount;
    private Integer followerCount;
    private Integer followingCount;

    public UserDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
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
    public Integer getBirdCount() { return birdCount; }
    public void setBirdCount(Integer birdCount) { this.birdCount = birdCount; }
    public Integer getPostCount() { return postCount; }
    public void setPostCount(Integer postCount) { this.postCount = postCount; }
    public Integer getFollowerCount() { return followerCount; }
    public void setFollowerCount(Integer followerCount) { this.followerCount = followerCount; }
    public Integer getFollowingCount() { return followingCount; }
    public void setFollowingCount(Integer followingCount) { this.followingCount = followingCount; }
}
