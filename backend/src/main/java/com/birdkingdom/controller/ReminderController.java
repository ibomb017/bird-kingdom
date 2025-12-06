package com.birdkingdom.controller;

import com.birdkingdom.dto.ReminderDTO;
import com.birdkingdom.service.ReminderService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/reminders")
@CrossOrigin(origins = "*")
public class ReminderController {

    private final ReminderService reminderService;

    public ReminderController(ReminderService reminderService) {
        this.reminderService = reminderService;
    }

    /** 获取所有提醒 */
    @GetMapping
    public ResponseEntity<List<ReminderDTO>> getAllReminders() {
        return ResponseEntity.ok(reminderService.getAllReminders());
    }

    /** 获取已启用的提醒 */
    @GetMapping("/enabled")
    public ResponseEntity<List<ReminderDTO>> getEnabledReminders() {
        return ResponseEntity.ok(reminderService.getEnabledReminders());
    }

    /** 获取单个提醒 */
    @GetMapping("/{id}")
    public ResponseEntity<ReminderDTO> getReminderById(@PathVariable Long id) {
        return ResponseEntity.ok(reminderService.getReminderById(id));
    }

    /** 创建提醒 */
    @PostMapping
    public ResponseEntity<ReminderDTO> createReminder(@Valid @RequestBody ReminderDTO dto) {
        return ResponseEntity.ok(reminderService.createReminder(dto));
    }

    /** 更新提醒 */
    @PutMapping("/{id}")
    public ResponseEntity<ReminderDTO> updateReminder(@PathVariable Long id, @Valid @RequestBody ReminderDTO dto) {
        return ResponseEntity.ok(reminderService.updateReminder(id, dto));
    }

    /** 切换提醒启用状态 */
    @PatchMapping("/{id}/toggle")
    public ResponseEntity<ReminderDTO> toggleReminder(@PathVariable Long id) {
        return ResponseEntity.ok(reminderService.toggleReminder(id));
    }

    /** 删除提醒 */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteReminder(@PathVariable Long id) {
        reminderService.deleteReminder(id);
        return ResponseEntity.noContent().build();
    }
}
