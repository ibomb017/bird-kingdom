package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 食物百科实体
 */
@Entity
@Table(name = "bird_foods")
public class FoodEncyclopedia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String category;

    @Column(name = "food_name", nullable = false, length = 100)
    private String foodName;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String intro;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String nutrition;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String precautions;

    @Column(name = "safety_level", nullable = false, length = 20)
    private String safetyLevel;

    @Column
    private Integer status = 1;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // Getters
    public Long getId() {
        return id;
    }

    public String getCategory() {
        return category;
    }

    public String getFoodName() {
        return foodName;
    }

    public String getIntro() {
        return intro;
    }

    public String getNutrition() {
        return nutrition;
    }

    public String getPrecautions() {
        return precautions;
    }

    public String getSafetyLevel() {
        return safetyLevel;
    }

    public Integer getStatus() {
        return status;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    // Setters
    public void setId(Long id) {
        this.id = id;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public void setFoodName(String foodName) {
        this.foodName = foodName;
    }

    public void setIntro(String intro) {
        this.intro = intro;
    }

    public void setNutrition(String nutrition) {
        this.nutrition = nutrition;
    }

    public void setPrecautions(String precautions) {
        this.precautions = precautions;
    }

    public void setSafetyLevel(String safetyLevel) {
        this.safetyLevel = safetyLevel;
    }

    public void setStatus(Integer status) {
        this.status = status;
    }
}
