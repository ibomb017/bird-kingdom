package com.birdkingdom.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "forum_posts")
public class ForumPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "post_type", length = 20)
    private String postType = "NORMAL";
    
    @Column(name = "media_type", length = 20)
    private String mediaType = "IMAGE"; // IMAGE, VIDEO
    
    @Column(name = "video_url", length = 500)
    private String videoUrl;
    
    @Column(name = "video_cover", length = 500)
    private String videoCover;
    
    @Column(name = "video_duration")
    private Integer videoDuration; // 视频时长（秒）

    @Column(name = "like_count")
    private Integer likeCount = 0;

    @Column(name = "comment_count")
    private Integer commentCount = 0;

    @Column(name = "view_count")
    private Integer viewCount = 0;

    @Column(precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "location_name", length = 100)
    private String locationName;

    @Column(name = "bird_name", length = 50)
    private String birdName;

    @Column(name = "bird_species", length = 50)
    private String birdSpecies;

    @Column(name = "lost_location", length = 200)
    private String lostLocation;

    @Column(name = "contact_phone", length = 20)
    private String contactPhone;

    @Column(length = 50)
    private String reward;

    @Column(name = "is_found")
    private Boolean isFound = false;

    @OneToMany(mappedBy = "post", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<PostImage> images = new ArrayList<>();

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public ForumPost() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public User getAuthor() { return author; }
    public void setAuthor(User author) { this.author = author; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getPostType() { return postType; }
    public void setPostType(String postType) { this.postType = postType; }
    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }
    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }
    public String getVideoCover() { return videoCover; }
    public void setVideoCover(String videoCover) { this.videoCover = videoCover; }
    public Integer getVideoDuration() { return videoDuration; }
    public void setVideoDuration(Integer videoDuration) { this.videoDuration = videoDuration; }
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
    public List<PostImage> getImages() { return images; }
    public void setImages(List<PostImage> images) { this.images = images; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (likeCount == null) likeCount = 0;
        if (commentCount == null) commentCount = 0;
        if (viewCount == null) viewCount = 0;
        if (isFound == null) isFound = false;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
