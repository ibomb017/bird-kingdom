package com.birdkingdom.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class ForumPostDTO {
    private Long id;
    private Long authorId;
    private String authorName;
    private String authorAvatar;
    private String content;
    private String postType;
    private List<String> images;
    private Integer likeCount;
    private Integer commentCount;
    private Integer viewCount;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private String locationName;
    private Double distance;
    private String birdName;
    private String birdSpecies;
    private String lostLocation;
    private String contactPhone;
    private String reward;
    private Boolean isFound;
    private Boolean isLiked;
    private Boolean isFavorited;
    private Boolean isFollowing;
    private LocalDateTime createdAt;
    private String timeAgo;

    public ForumPostDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getAuthorId() { return authorId; }
    public void setAuthorId(Long authorId) { this.authorId = authorId; }
    public String getAuthorName() { return authorName; }
    public void setAuthorName(String authorName) { this.authorName = authorName; }
    public String getAuthorAvatar() { return authorAvatar; }
    public void setAuthorAvatar(String authorAvatar) { this.authorAvatar = authorAvatar; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getPostType() { return postType; }
    public void setPostType(String postType) { this.postType = postType; }
    public List<String> getImages() { return images; }
    public void setImages(List<String> images) { this.images = images; }
    public Integer getLikeCount() { return likeCount; }
    public void setLikeCount(Integer likeCount) { this.likeCount = likeCount; }
    public Integer getCommentCount() { return commentCount; }
    public void setCommentCount(Integer commentCount) { this.commentCount = commentCount; }
    public Integer getViewCount() { return viewCount; }
    public void setViewCount(Integer viewCount) { this.viewCount = viewCount; }
    public BigDecimal getLatitude() { return latitude; }
    public void setLatitude(BigDecimal latitude) { this.latitude = latitude; }
    public BigDecimal getLongitude() { return longitude; }
    public void setLongitude(BigDecimal longitude) { this.longitude = longitude; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    public Double getDistance() { return distance; }
    public void setDistance(Double distance) { this.distance = distance; }
    public String getBirdName() { return birdName; }
    public void setBirdName(String birdName) { this.birdName = birdName; }
    public String getBirdSpecies() { return birdSpecies; }
    public void setBirdSpecies(String birdSpecies) { this.birdSpecies = birdSpecies; }
    public String getLostLocation() { return lostLocation; }
    public void setLostLocation(String lostLocation) { this.lostLocation = lostLocation; }
    public String getContactPhone() { return contactPhone; }
    public void setContactPhone(String contactPhone) { this.contactPhone = contactPhone; }
    public String getReward() { return reward; }
    public void setReward(String reward) { this.reward = reward; }
    public Boolean getIsFound() { return isFound; }
    public void setIsFound(Boolean isFound) { this.isFound = isFound; }
    public Boolean getIsLiked() { return isLiked; }
    public void setIsLiked(Boolean isLiked) { this.isLiked = isLiked; }
    public Boolean getIsFavorited() { return isFavorited; }
    public void setIsFavorited(Boolean isFavorited) { this.isFavorited = isFavorited; }
    public Boolean getIsFollowing() { return isFollowing; }
    public void setIsFollowing(Boolean isFollowing) { this.isFollowing = isFollowing; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public String getTimeAgo() { return timeAgo; }
    public void setTimeAgo(String timeAgo) { this.timeAgo = timeAgo; }
}
