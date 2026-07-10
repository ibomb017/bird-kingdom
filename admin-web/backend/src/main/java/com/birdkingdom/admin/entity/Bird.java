package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 鸟儿实体 (只读)
 */
@Entity
@Table(name = "birds")
public class Bird {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String nickname;

    @Column(nullable = false, length = 50)
    private String species;

    @Column(length = 20)
    private String gender;

    @Column(name = "hatch_date")
    private LocalDate hatchDate;

    @Column(name = "adoption_date")
    private LocalDate adoptionDate;

    @Column(name = "feather_color", length = 50)
    private String featherColor;

    @Column(name = "avatar_url", length = 255)
    private String avatarUrl;

    @Column(name = "is_deleted")
    private Boolean isDeleted = false;

    @Column(name = "is_lost")
    private Boolean isLost = false;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Getters
    public Long getId() {
        return id;
    }

    public String getNickname() {
        return nickname;
    }

    public String getSpecies() {
        return species;
    }

    public String getGender() {
        return gender;
    }

    public LocalDate getHatchDate() {
        return hatchDate;
    }

    public LocalDate getAdoptionDate() {
        return adoptionDate;
    }

    public String getFeatherColor() {
        return featherColor;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public Boolean getIsDeleted() {
        return isDeleted;
    }

    public Boolean getIsLost() {
        return isLost;
    }

    public Long getUserId() {
        return userId;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }
}
