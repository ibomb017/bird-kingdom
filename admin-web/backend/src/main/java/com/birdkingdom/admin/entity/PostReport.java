package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 帖子举报实体 (只读)
 */
@Entity
@Table(name = "post_reports")
public class PostReport {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "reporter_id", nullable = false)
    private Long reporterId;

    @Column(nullable = false, length = 50)
    private String reason;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(length = 20)
    private String status = "PENDING"; // PENDING, REVIEWED, REJECTED, APPROVED

    @Column(name = "review_note", columnDefinition = "TEXT")
    private String reviewNote; // 审核备注

    @Column(name = "reviewer_id")
    private Long reviewerId; // 审核员ID

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt; // 审核时间

    @Column(name = "handled_at")
    private LocalDateTime handledAt;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public Long getPostId() {
        return postId;
    }

    public Long getReporterId() {
        return reporterId;
    }

    public String getReason() {
        return reason;
    }

    public String getDescription() {
        return description;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getHandledAt() {
        return handledAt;
    }

    public void setHandledAt(LocalDateTime handledAt) {
        this.handledAt = handledAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public String getReviewNote() {
        return reviewNote;
    }

    public void setReviewNote(String reviewNote) {
        this.reviewNote = reviewNote;
    }

    public Long getReviewerId() {
        return reviewerId;
    }

    public void setReviewerId(Long reviewerId) {
        this.reviewerId = reviewerId;
    }

    public LocalDateTime getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(LocalDateTime reviewedAt) {
        this.reviewedAt = reviewedAt;
    }
}
