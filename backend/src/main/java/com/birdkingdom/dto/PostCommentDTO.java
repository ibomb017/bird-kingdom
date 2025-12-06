package com.birdkingdom.dto;

import java.time.LocalDateTime;
import java.util.List;

public class PostCommentDTO {
    private Long id;
    private Long postId;
    private Long authorId;
    private String authorName;
    private String authorAvatar;
    private String content;
    private Integer likeCount;
    private Long parentId;
    private List<PostCommentDTO> replies;
    private Boolean isLiked;
    private LocalDateTime createdAt;
    private String timeAgo;

    public PostCommentDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getPostId() { return postId; }
    public void setPostId(Long postId) { this.postId = postId; }
    public Long getAuthorId() { return authorId; }
    public void setAuthorId(Long authorId) { this.authorId = authorId; }
    public String getAuthorName() { return authorName; }
    public void setAuthorName(String authorName) { this.authorName = authorName; }
    public String getAuthorAvatar() { return authorAvatar; }
    public void setAuthorAvatar(String authorAvatar) { this.authorAvatar = authorAvatar; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public Integer getLikeCount() { return likeCount; }
    public void setLikeCount(Integer likeCount) { this.likeCount = likeCount; }
    public Long getParentId() { return parentId; }
    public void setParentId(Long parentId) { this.parentId = parentId; }
    public List<PostCommentDTO> getReplies() { return replies; }
    public void setReplies(List<PostCommentDTO> replies) { this.replies = replies; }
    public Boolean getIsLiked() { return isLiked; }
    public void setIsLiked(Boolean isLiked) { this.isLiked = isLiked; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public String getTimeAgo() { return timeAgo; }
    public void setTimeAgo(String timeAgo) { this.timeAgo = timeAgo; }
}
