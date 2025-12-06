package com.birdkingdom.dto;

public class ColorGeneDTO {
    private Long id;
    private String name;
    private String code;
    private String displayColor;
    private Boolean isDominant;
    private String description;

    public ColorGeneDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public String getDisplayColor() { return displayColor; }
    public void setDisplayColor(String displayColor) { this.displayColor = displayColor; }
    public Boolean getIsDominant() { return isDominant; }
    public void setIsDominant(Boolean isDominant) { this.isDominant = isDominant; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
}
