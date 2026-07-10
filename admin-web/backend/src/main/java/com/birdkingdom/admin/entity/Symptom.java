package com.birdkingdom.admin.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 症状百科实体 (只读)
 */
@Entity
@Table(name = "symptoms")
public class Symptom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "possible_causes", columnDefinition = "TEXT")
    private String possibleCauses;

    @Column(columnDefinition = "TEXT")
    private String suggestions;

    @Column(name = "when_to_see_vet", columnDefinition = "TEXT")
    private String whenToSeeVet;

    @Column(length = 20)
    private String severity;

    @Column(length = 50)
    private String category;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Getters
    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public String getPossibleCauses() {
        return possibleCauses;
    }

    public String getSuggestions() {
        return suggestions;
    }

    public String getWhenToSeeVet() {
        return whenToSeeVet;
    }

    public String getSeverity() {
        return severity;
    }

    public String getCategory() {
        return category;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    // Setters for admin operations
    public void setName(String name) {
        this.name = name;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setPossibleCauses(String possibleCauses) {
        this.possibleCauses = possibleCauses;
    }

    public void setSuggestions(String suggestions) {
        this.suggestions = suggestions;
    }

    public void setWhenToSeeVet(String whenToSeeVet) {
        this.whenToSeeVet = whenToSeeVet;
    }

    public void setSeverity(String severity) {
        this.severity = severity;
    }

    public void setCategory(String category) {
        this.category = category;
    }
}
