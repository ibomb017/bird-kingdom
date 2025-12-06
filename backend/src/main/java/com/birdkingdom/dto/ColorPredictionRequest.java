package com.birdkingdom.dto;

public class ColorPredictionRequest {
    private String fatherColorCode;
    private String motherColorCode;

    public ColorPredictionRequest() {}

    public String getFatherColorCode() { return fatherColorCode; }
    public void setFatherColorCode(String fatherColorCode) { this.fatherColorCode = fatherColorCode; }
    public String getMotherColorCode() { return motherColorCode; }
    public void setMotherColorCode(String motherColorCode) { this.motherColorCode = motherColorCode; }
}
