package com.birdkingdom.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class BirdLogDTO {
    private Long id;
    @NotNull(message = "鸟ID不能为空")
    private Long birdId;
    private String birdName;
    @NotNull(message = "日志日期不能为空")
    private LocalDate logDate;
    private BigDecimal weight;
    private BigDecimal feedAmount;
    private BigDecimal waterAmount;
    private String mood;
    private String behavior;
    private Boolean isMolting;
    private Boolean isBreeding;
    private BigDecimal temperature;
    private BigDecimal humidity;
    private Boolean isCleaned;
    private Integer healthScore;
    private String notes;
    private LocalDateTime createdAt;

    public BirdLogDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getBirdId() { return birdId; }
    public void setBirdId(Long birdId) { this.birdId = birdId; }
    public String getBirdName() { return birdName; }
    public void setBirdName(String birdName) { this.birdName = birdName; }
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
}
