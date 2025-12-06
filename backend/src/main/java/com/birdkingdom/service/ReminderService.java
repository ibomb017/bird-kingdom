package com.birdkingdom.service;

import com.birdkingdom.dto.ReminderDTO;
import com.birdkingdom.entity.Bird;
import com.birdkingdom.entity.Reminder;
import com.birdkingdom.repository.BirdRepository;
import com.birdkingdom.repository.ReminderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ReminderService {

    private final ReminderRepository reminderRepository;
    private final BirdRepository birdRepository;

    public ReminderService(ReminderRepository reminderRepository, BirdRepository birdRepository) {
        this.reminderRepository = reminderRepository;
        this.birdRepository = birdRepository;
    }

    public List<ReminderDTO> getAllReminders() {
        return reminderRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<ReminderDTO> getEnabledReminders() {
        return reminderRepository.findByEnabledTrue()
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public ReminderDTO getReminderById(Long id) {
        Reminder reminder = reminderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("提醒不存在: " + id));
        return toDTO(reminder);
    }

    @Transactional
    public ReminderDTO createReminder(ReminderDTO dto) {
        Reminder reminder = new Reminder();
        updateEntityFromDTO(reminder, dto);
        reminder = reminderRepository.save(reminder);
        return toDTO(reminder);
    }

    @Transactional
    public ReminderDTO updateReminder(Long id, ReminderDTO dto) {
        Reminder reminder = reminderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("提醒不存在: " + id));
        updateEntityFromDTO(reminder, dto);
        reminder = reminderRepository.save(reminder);
        return toDTO(reminder);
    }

    @Transactional
    public ReminderDTO toggleReminder(Long id) {
        Reminder reminder = reminderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("提醒不存在: " + id));
        reminder.setEnabled(!reminder.getEnabled());
        reminder = reminderRepository.save(reminder);
        return toDTO(reminder);
    }

    @Transactional
    public void deleteReminder(Long id) {
        if (!reminderRepository.existsById(id)) {
            throw new RuntimeException("提醒不存在: " + id);
        }
        reminderRepository.deleteById(id);
    }

    private ReminderDTO toDTO(Reminder reminder) {
        ReminderDTO dto = new ReminderDTO();
        dto.setId(reminder.getId());
        dto.setTitle(reminder.getTitle());
        dto.setTimeDescription(reminder.getTimeDescription());
        dto.setReminderType(reminder.getReminderType());
        dto.setEnabled(reminder.getEnabled());
        if (reminder.getBird() != null) {
            dto.setBirdId(reminder.getBird().getId());
            dto.setBirdName(reminder.getBird().getNickname());
        }
        return dto;
    }

    private void updateEntityFromDTO(Reminder reminder, ReminderDTO dto) {
        reminder.setTitle(dto.getTitle());
        reminder.setTimeDescription(dto.getTimeDescription());
        reminder.setReminderType(dto.getReminderType());
        reminder.setEnabled(dto.getEnabled() != null ? dto.getEnabled() : true);

        if (dto.getBirdId() != null) {
            Bird bird = birdRepository.findById(dto.getBirdId())
                    .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + dto.getBirdId()));
            reminder.setBird(bird);
        } else {
            reminder.setBird(null);
        }
    }
}
