package com.birdkingdom.dto;

import java.util.List;

public class ColorPredictionResult {
    private List<PredictedColor> predictions;

    public ColorPredictionResult() {}
    public ColorPredictionResult(List<PredictedColor> predictions) { this.predictions = predictions; }

    public List<PredictedColor> getPredictions() { return predictions; }
    public void setPredictions(List<PredictedColor> predictions) { this.predictions = predictions; }

    public static class PredictedColor {
        private String name;
        private String colorHex;
        private int percentage;
        public PredictedColor() {}
        public PredictedColor(String name, String colorHex, int percentage) {
            this.name = name; this.colorHex = colorHex; this.percentage = percentage;
        }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getColorHex() { return colorHex; }
        public void setColorHex(String colorHex) { this.colorHex = colorHex; }
        public int getPercentage() { return percentage; }
        public void setPercentage(int percentage) { this.percentage = percentage; }
    }
}
