package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 开屏展示位实体 (只读)
 */
@Entity
@Table(name = "splash_display_slot")
public class SplashDisplaySlot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "display_date", nullable = false)
    private LocalDate displayDate;

    @Column(name = "image_url", length = 512)
    private String imageUrl;

    @Column(name = "review_status", length = 20)
    private String reviewStatus;

    @Column(name = "review_reason", length = 500)
    private String reviewReason;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    @Column(name = "order_id", nullable = false)
    private Long orderId;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "slot_number", nullable = false)
    private Integer slotNumber;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public LocalDate getDisplayDate() {
        return displayDate;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public String getReviewStatus() {
        return reviewStatus;
    }

    public void setReviewStatus(String reviewStatus) {
        this.reviewStatus = reviewStatus;
    }

    public String getReviewReason() {
        return reviewReason;
    }

    public void setReviewReason(String reviewReason) {
        this.reviewReason = reviewReason;
    }

    public LocalDateTime getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(LocalDateTime reviewedAt) {
        this.reviewedAt = reviewedAt;
    }

    public Long getOrderId() {
        return orderId;
    }

    public String getStatus() {
        return status;
    }

    public Integer getSlotNumber() {
        return slotNumber;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    // Additional setters for admin operations
    public void setStatus(String status) {
        this.status = status;
    }
}
