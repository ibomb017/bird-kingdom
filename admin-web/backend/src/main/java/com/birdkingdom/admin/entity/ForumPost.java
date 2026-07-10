package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 论坛帖子实体 (只读)
 */
@Entity
@Table(name = "forum_posts")
public class ForumPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "author_id", nullable = false)
    private Long authorId;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "post_type", length = 20)
    private String postType = "NORMAL";

    @Column(name = "media_type", length = 20)
    private String mediaType = "IMAGE";

    @Column(name = "video_url", length = 500)
    private String videoUrl;

    @Column(name = "like_count")
    private Integer likeCount = 0;

    @Column(name = "comment_count")
    private Integer commentCount = 0;

    @Column(name = "view_count")
    private Integer viewCount = 0;

    @Column(name = "location_name", length = 100)
    private String locationName;

    @Column(name = "bird_name", length = 50)
    private String birdName;

    @Column(name = "bird_species", length = 50)
    private String birdSpecies;

    @Column(name = "lost_location", length = 200)
    private String lostLocation;

    @Column(name = "is_found")
    private Boolean isFound = false;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Getters
    public Long getId() {
        return id;
    }

    public Long getAuthorId() {
        return authorId;
    }

    public String getContent() {
        return content;
    }

    public String getPostType() {
        return postType;
    }

    public String getMediaType() {
        return mediaType;
    }

    public String getVideoUrl() {
        return videoUrl;
    }

    public Integer getLikeCount() {
        return likeCount;
    }

    public Integer getCommentCount() {
        return commentCount;
    }

    public Integer getViewCount() {
        return viewCount;
    }

    public String getLocationName() {
        return locationName;
    }

    public String getBirdName() {
        return birdName;
    }

    public String getBirdSpecies() {
        return birdSpecies;
    }

    public String getLostLocation() {
        return lostLocation;
    }

    public Boolean getIsFound() {
        return isFound;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    // 添加必要的setters
    public void setCommentCount(Integer commentCount) {
        this.commentCount = commentCount;
    }

    public void setLikeCount(Integer likeCount) {
        this.likeCount = likeCount;
    }

    public void setViewCount(Integer viewCount) {
        this.viewCount = viewCount;
    }

    public String getMediaUrls() {
        // 兼容性方法：返回视频URL或其他媒体
        return videoUrl;
    }

    public Integer getFavoriteCount() {
        // 兼容性：目前返回0
        return 0;
    }
}
