package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "parrot_species")
public class ParrotSpecies {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 50)
    private String category;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "weight_min", precision = 6, scale = 1)
    private BigDecimal weightMin;

    @Column(name = "weight_max", precision = 6, scale = 1)
    private BigDecimal weightMax;

    @Column(name = "molting_duration_min")
    private Integer moltingDurationMin;

    @Column(name = "molting_duration_max")
    private Integer moltingDurationMax;

    @Column(name = "molting_cycle_min")
    private Integer moltingCycleMin;

    @Column(name = "molting_cycle_max")
    private Integer moltingCycleMax;

    @Column(name = "incubation_days")
    private Integer incubationDays;

    @Column(name = "clutch_size_min")
    private Integer clutchSizeMin;

    @Column(name = "clutch_size_max")
    private Integer clutchSizeMax;

    @Column(name = "estrus_cycle_min")
    private Integer estrusCycleMin;

    @Column(name = "estrus_cycle_max")
    private Integer estrusCycleMax;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Getters and Setters
    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public BigDecimal getWeightMin() {
        return weightMin;
    }

    public void setWeightMin(BigDecimal weightMin) {
        this.weightMin = weightMin;
    }

    public BigDecimal getWeightMax() {
        return weightMax;
    }

    public void setWeightMax(BigDecimal weightMax) {
        this.weightMax = weightMax;
    }

    public Integer getMoltingDurationMin() {
        return moltingDurationMin;
    }

    public void setMoltingDurationMin(Integer moltingDurationMin) {
        this.moltingDurationMin = moltingDurationMin;
    }

    public Integer getMoltingDurationMax() {
        return moltingDurationMax;
    }

    public void setMoltingDurationMax(Integer moltingDurationMax) {
        this.moltingDurationMax = moltingDurationMax;
    }

    public Integer getMoltingCycleMin() {
        return moltingCycleMin;
    }

    public void setMoltingCycleMin(Integer moltingCycleMin) {
        this.moltingCycleMin = moltingCycleMin;
    }

    public Integer getMoltingCycleMax() {
        return moltingCycleMax;
    }

    public void setMoltingCycleMax(Integer moltingCycleMax) {
        this.moltingCycleMax = moltingCycleMax;
    }

    public Integer getIncubationDays() {
        return incubationDays;
    }

    public void setIncubationDays(Integer incubationDays) {
        this.incubationDays = incubationDays;
    }

    public Integer getClutchSizeMin() {
        return clutchSizeMin;
    }

    public void setClutchSizeMin(Integer clutchSizeMin) {
        this.clutchSizeMin = clutchSizeMin;
    }

    public Integer getClutchSizeMax() {
        return clutchSizeMax;
    }

    public void setClutchSizeMax(Integer clutchSizeMax) {
        this.clutchSizeMax = clutchSizeMax;
    }

    public Integer getEstrusCycleMin() {
        return estrusCycleMin;
    }

    public void setEstrusCycleMin(Integer estrusCycleMin) {
        this.estrusCycleMin = estrusCycleMin;
    }

    public Integer getEstrusCycleMax() {
        return estrusCycleMax;
    }

    public void setEstrusCycleMax(Integer estrusCycleMax) {
        this.estrusCycleMax = estrusCycleMax;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
