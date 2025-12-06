package com.birdkingdom.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "bird_logs")
public class BirdLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "bird_id", nullable = false)
    private Bird bird;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    @Column(precision = 5, scale = 2)
    private BigDecimal weight;

    @Column(name = "feed_amount", precision = 5, scale = 2)
    private BigDecimal feedAmount;

    @Column(name = "water_amount", precision = 5, scale = 2)
    private BigDecimal waterAmount;

    @Column(length = 20)
    private String mood;

    @Column(columnDefinition = "TEXT")
    private String behavior;

    @Column(name = "is_molting")
    private Boolean isMolting;

    @Column(name = "is_breeding")
    private Boolean isBreeding;

    @Column(precision = 4, scale = 1)
    private BigDecimal temperature;

    @Column(precision = 4, scale = 1)
    private BigDecimal humidity;

    @Column(name = "is_cleaned")
    private Boolean isCleaned;

    @Column(name = "health_score")
    private Integer healthScore;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public BirdLog() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Bird getBird() { return bird; }
    public void setBird(Bird bird) { this.bird = bird; }
    public LocalDate getLogDate() { return logDate; }
    public void setLogDate(LocalDate logDate) { this.logDate = logDate; }
    public BigDecimal getWeight() { return weight; }
    public void setWeight(BigDecimal weight) { this.weight = weight; }
    public BigDecimal getFeedAmount() { return feedAmount; }
    public void setFeedAmount(BigDecimal feedAmount) { this.feedAmount = feedAmount; }
    public BigDecimal getWaterAmount() { return waterAmount; }
    public void setWaterAmount(BigDecimal waterAmount) { this.waterAmount = waterAmount; }
    public String getMood() { return mood; }
    public void setMood(String mood) { this.mood = mood; }
    public String getBehavior() { return behavior; }
    public void setBehavior(String behavior) { this.behavior = behavior; }
    public Boolean getIsMolting() { return isMolting; }
    public void setIsMolting(Boolean isMolting) { this.isMolting = isMolting; }
    public Boolean getIsBreeding() { return isBreeding; }
    public void setIsBreeding(Boolean isBreeding) { this.isBreeding = isBreeding; }
    public BigDecimal getTemperature() { return temperature; }
    public void setTemperature(BigDecimal temperature) { this.temperature = temperature; }
    public BigDecimal getHumidity() { return humidity; }
    public void setHumidity(BigDecimal humidity) { this.humidity = humidity; }
    public Boolean getIsCleaned() { return isCleaned; }
    public void setIsCleaned(Boolean isCleaned) { this.isCleaned = isCleaned; }
    public Integer getHealthScore() { return healthScore; }
    public void setHealthScore(Integer healthScore) { this.healthScore = healthScore; }
    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
