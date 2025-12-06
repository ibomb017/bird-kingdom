package com.birdkingdom.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

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
    
    @Column(name = "birthday_type", length = 20)
    private String birthdayType; // HATCH 或 ADOPTION

    @Column(name = "feather_color", length = 50)
    private String featherColor;

    @Column(length = 100)
    private String source;

    @Column(name = "father_info", length = 100)
    private String fatherInfo;

    @Column(name = "mother_info", length = 100)
    private String motherInfo;

    @Column(name = "avatar_url", length = 255)
    private String avatarUrl;

    @Column(columnDefinition = "TEXT")
    private String notes;
    
    @Column(name = "death_date")
    private LocalDate deathDate;
    
    @Column(name = "is_deleted")
    private Boolean isDeleted = false;
    
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
    
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public Bird() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public String getSpecies() { return species; }
    public void setSpecies(String species) { this.species = species; }
    public String getGender() { return gender; }
    public void setGender(String gender) { this.gender = gender; }
    public LocalDate getHatchDate() { return hatchDate; }
    public void setHatchDate(LocalDate hatchDate) { this.hatchDate = hatchDate; }
    public LocalDate getAdoptionDate() { return adoptionDate; }
    public void setAdoptionDate(LocalDate adoptionDate) { this.adoptionDate = adoptionDate; }
    public String getBirthdayType() { return birthdayType; }
    public void setBirthdayType(String birthdayType) { this.birthdayType = birthdayType; }
    public String getFeatherColor() { return featherColor; }
    public void setFeatherColor(String featherColor) { this.featherColor = featherColor; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public String getFatherInfo() { return fatherInfo; }
    public void setFatherInfo(String fatherInfo) { this.fatherInfo = fatherInfo; }
    public String getMotherInfo() { return motherInfo; }
    public void setMotherInfo(String motherInfo) { this.motherInfo = motherInfo; }
    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }
    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
    public LocalDate getDeathDate() { return deathDate; }
    public void setDeathDate(LocalDate deathDate) { this.deathDate = deathDate; }
    public Boolean getIsDeleted() { return isDeleted; }
    public void setIsDeleted(Boolean isDeleted) { this.isDeleted = isDeleted; }
    public LocalDateTime getDeletedAt() { return deletedAt; }
    public void setDeletedAt(LocalDateTime deletedAt) { this.deletedAt = deletedAt; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (isDeleted == null) {
            isDeleted = false;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
