package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.*;
import com.birdkingdom.admin.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 鸟日志控制器 - 真实数据
 */
@RestController
@RequestMapping("/api/admin/bird-logs")
public class BirdLogController {

    @Autowired
    private BirdLogRepository birdLogRepository;

    @Autowired
    private BirdRepository birdRepository;

    /**
     * 获取日志列表
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getLogs(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) Long birdId) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "logDate"));
        Page<BirdLog> logPage;

        if (birdId != null) {
            logPage = birdLogRepository.findByBirdId(birdId, pageRequest);
        } else {
            logPage = birdLogRepository.findAll(pageRequest);
        }

        List<Map<String, Object>> logs = new ArrayList<>();
        for (BirdLog log : logPage.getContent()) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", log.getId());
            item.put("birdId", log.getBirdId());
            item.put("logDate", log.getLogDate());
            item.put("weight", log.getWeight());
            item.put("mood", log.getMood());
            item.put("behavior", log.getBehavior());
            item.put("healthScore", log.getHealthScore());
            item.put("notes", log.getNotes());
            item.put("createdAt", log.getCreatedAt());

            birdRepository.findById(log.getBirdId()).ifPresent(bird -> {
                item.put("birdNickname", bird.getNickname());
                item.put("birdSpecies", bird.getSpecies());
            });

            logs.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", logs);
        result.put("totalElements", logPage.getTotalElements());
        result.put("totalPages", logPage.getTotalPages());

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
    }

    /**
     * 获取日志详情
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getLogDetail(@PathVariable Long id) {
        Optional<BirdLog> logOpt = birdLogRepository.findById(id);
        if (logOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "日志不存在"));
        }

        BirdLog log = logOpt.get();
        Map<String, Object> detail = new HashMap<>();
        detail.put("id", log.getId());
        detail.put("birdId", log.getBirdId());
        detail.put("logDate", log.getLogDate());
        detail.put("weight", log.getWeight());
        detail.put("mood", log.getMood());
        detail.put("behavior", log.getBehavior());
        detail.put("healthScore", log.getHealthScore());
        detail.put("notes", log.getNotes());
        detail.put("createdAt", log.getCreatedAt());

        birdRepository.findById(log.getBirdId()).ifPresent(bird -> {
            detail.put("birdNickname", bird.getNickname());
            detail.put("birdSpecies", bird.getSpecies());
            detail.put("birdAvatarUrl", bird.getAvatarUrl());
        });

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", detail));
    }
}
