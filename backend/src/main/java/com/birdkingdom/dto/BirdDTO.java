package com.birdkingdom.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class BirdDTO {
    private Long id;
    @NotBlank(message = "昵称不能为空")
    private String nickname;
    @NotBlank(message = "品种不能为空")
    private String species;
    private String gender;
    private LocalDate hatchDate;
    private LocalDate adoptionDate;
    private String birthdayType; // HATCH 或 ADOPTION
    private LocalDate deathDate;
    private String featherColor;
    private String source;
    private String fatherInfo;
    private String motherInfo;
    private String avatarUrl;
    private String notes;
    private Integer ageMonths;
    private Boolean isDeleted;
    private LocalDateTime deletedAt;
    private Long userId;

    public BirdDTO() {}

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
    public Integer getAgeMonths() { return ageMonths; }
    public void setAgeMonths(Integer ageMonths) { this.ageMonths = ageMonths; }
    public LocalDate getDeathDate() { return deathDate; }
    public void setDeathDate(LocalDate deathDate) { this.deathDate = deathDate; }
    public Boolean getIsDeleted() { return isDeleted; }
    public void setIsDeleted(Boolean isDeleted) { this.isDeleted = isDeleted; }
    public LocalDateTime getDeletedAt() { return deletedAt; }
    public void setDeletedAt(LocalDateTime deletedAt) { this.deletedAt = deletedAt; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
}
