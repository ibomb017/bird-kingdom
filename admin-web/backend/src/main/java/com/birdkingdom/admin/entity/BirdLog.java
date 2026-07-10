package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 鸟日志实体 (只读)
 */
@Entity
@Table(name = "bird_logs")
public class BirdLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "bird_id", nullable = false)
    private Long birdId;

    @Column(name = "log_date", nullable = false)
    private LocalDateTime logDate;

    @Column(precision = 5, scale = 2)
    private BigDecimal weight;

    @Column(length = 20)
    private String mood;

    @Column(columnDefinition = "TEXT")
    private String behavior;

    @Column(name = "health_score")
    private Integer healthScore;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Getters
    public Long getId() {
        return id;
    }

    public Long getBirdId() {
        return birdId;
    }

    public LocalDateTime getLogDate() {
        return logDate;
    }

    public BigDecimal getWeight() {
        return weight;
    }

    public String getMood() {
        return mood;
    }

    public String getBehavior() {
        return behavior;
    }

    public Integer getHealthScore() {
        return healthScore;
    }

    public String getNotes() {
        return notes;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}
