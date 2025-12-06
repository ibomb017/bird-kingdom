package com.birdkingdom.dto;

import jakarta.validation.constraints.NotBlank;

public class ReminderDTO {
    private Long id;
    @NotBlank(message = "提醒标题不能为空")
    private String title;
    @NotBlank(message = "提醒时间不能为空")
    private String timeDescription;
    private String reminderType;
    private Boolean enabled;
    private Long birdId;
    private String birdName;

    public ReminderDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getTimeDescription() { return timeDescription; }
    public void setTimeDescription(String timeDescription) { this.timeDescription = timeDescription; }
    public String getReminderType() { return reminderType; }
    public void setReminderType(String reminderType) { this.reminderType = reminderType; }
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    public Long getBirdId() { return birdId; }
    public void setBirdId(Long birdId) { this.birdId = birdId; }
    public String getBirdName() { return birdName; }
    public void setBirdName(String birdName) { this.birdName = birdName; }
}
