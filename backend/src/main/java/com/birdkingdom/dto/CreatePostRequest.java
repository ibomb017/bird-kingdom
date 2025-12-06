package com.birdkingdom.dto;

import java.math.BigDecimal;
import java.util.List;

public class CreatePostRequest {
    private String content;
    private String postType;
    private List<String> images;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private String locationName;
    private String birdName;
    private String birdSpecies;
    private String lostLocation;
    private String contactPhone;
    private String reward;

    public CreatePostRequest() {}

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getPostType() { return postType; }
    public void setPostType(String postType) { this.postType = postType; }
    public List<String> getImages() { return images; }
    public void setImages(List<String> images) { this.images = images; }
    public BigDecimal getLatitude() { return latitude; }
    public void setLatitude(BigDecimal latitude) { this.latitude = latitude; }
    public BigDecimal getLongitude() { return longitude; }
    public void setLongitude(BigDecimal longitude) { this.longitude = longitude; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    public String getBirdName() { return birdName; }
    public void setBirdName(String birdName) { this.birdName = birdName; }
    public String getBirdSpecies() { return birdSpecies; }
    public void setBirdSpecies(String birdSpecies) { this.birdSpecies = birdSpecies; }
    public String getLostLocation() { return lostLocation; }
    public void setLostLocation(String lostLocation) { this.lostLocation = lostLocation; }
    public String getContactPhone() { return contactPhone; }
    public void setContactPhone(String contactPhone) { this.contactPhone = contactPhone; }
    public String getReward() { return reward; }
    public void setReward(String reward) { this.reward = reward; }
}
