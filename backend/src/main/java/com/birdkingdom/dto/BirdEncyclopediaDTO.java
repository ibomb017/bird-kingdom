package com.birdkingdom.dto;

import java.util.List;

public class BirdEncyclopediaDTO {
    private Long id;
    private String name;
    private String scientificName;
    private String category;
    private List<String> tags;
    private String description;
    private String feedingTips;
    private String habitat;
    private Integer lifespan;
    private String colorHex;
    private String imageUrl;

    public BirdEncyclopediaDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getScientificName() { return scientificName; }
    public void setScientificName(String scientificName) { this.scientificName = scientificName; }
    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
    public List<String> getTags() { return tags; }
    public void setTags(List<String> tags) { this.tags = tags; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getFeedingTips() { return feedingTips; }
    public void setFeedingTips(String feedingTips) { this.feedingTips = feedingTips; }
    public String getHabitat() { return habitat; }
    public void setHabitat(String habitat) { this.habitat = habitat; }
    public Integer getLifespan() { return lifespan; }
    public void setLifespan(Integer lifespan) { this.lifespan = lifespan; }
    public String getColorHex() { return colorHex; }
    public void setColorHex(String colorHex) { this.colorHex = colorHex; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
}
