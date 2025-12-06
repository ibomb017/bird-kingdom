package com.birdkingdom.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public class WeightTrendDTO {
    private Long birdId;
    private String birdName;
    private List<WeightPoint> points;

    public WeightTrendDTO() {}

    public Long getBirdId() { return birdId; }
    public void setBirdId(Long birdId) { this.birdId = birdId; }
    public String getBirdName() { return birdName; }
    public void setBirdName(String birdName) { this.birdName = birdName; }
    public List<WeightPoint> getPoints() { return points; }
    public void setPoints(List<WeightPoint> points) { this.points = points; }

    public static class WeightPoint {
        private LocalDate date;
        private BigDecimal weight;
        public WeightPoint() {}
        public WeightPoint(LocalDate date, BigDecimal weight) { this.date = date; this.weight = weight; }
        public LocalDate getDate() { return date; }
        public void setDate(LocalDate date) { this.date = date; }
        public BigDecimal getWeight() { return weight; }
        public void setWeight(BigDecimal weight) { this.weight = weight; }
    }
}
