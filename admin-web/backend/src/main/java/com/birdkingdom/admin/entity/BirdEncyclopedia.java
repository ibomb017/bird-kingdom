package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 品种百科实体 (只读)
 */
@Entity
@Table(name = "bird_encyclopedia")
public class BirdEncyclopedia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(name = "scientific_name", length = 100)
    private String scientificName;

    @Column(length = 50)
    private String category;

    @Column(length = 200)
    private String tags;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "feeding_tips", columnDefinition = "TEXT")
    private String feedingTips;

    @Column(length = 100)
    private String habitat;

    private Integer lifespan;

    @Column(name = "image_url", length = 255)
    private String imageUrl;

    @Column(name = "price_min")
    private Integer priceMin;

    @Column(name = "price_max")
    private Integer priceMax;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Getters
    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getScientificName() {
        return scientificName;
    }

    public String getCategory() {
        return category;
    }

    public String getTags() {
        return tags;
    }

    public String getDescription() {
        return description;
    }

    public String getFeedingTips() {
        return feedingTips;
    }

    public String getHabitat() {
        return habitat;
    }

    public Integer getLifespan() {
        return lifespan;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public Integer getPriceMin() {
        return priceMin;
    }

    public Integer getPriceMax() {
        return priceMax;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    // Setters for admin operations
    public void setName(String name) {
        this.name = name;
    }

    public void setScientificName(String scientificName) {
        this.scientificName = scientificName;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public void setTags(String tags) {
        this.tags = tags;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setFeedingTips(String feedingTips) {
        this.feedingTips = feedingTips;
    }

    public void setHabitat(String habitat) {
        this.habitat = habitat;
    }

    public void setLifespan(String lifespan) {
        try {
            this.lifespan = Integer.parseInt(lifespan);
        } catch (Exception e) {
            this.lifespan = null;
        }
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public void setPriceMin(Integer priceMin) {
        this.priceMin = priceMin;
    }

    public void setPriceMax(Integer priceMax) {
        this.priceMax = priceMax;
    }
}
