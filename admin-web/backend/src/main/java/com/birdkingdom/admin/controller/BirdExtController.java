package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.repository.BirdRepository;
import com.birdkingdom.admin.repository.BirdLogRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 鸟类&日志管理扩展Controller - 补充删除和统计功能
 */
@RestController
@RequestMapping("/api/admin/birds")
public class BirdExtController {

    @Autowired
    private BirdRepository birdRepository;

    @Autowired
    private BirdLogRepository birdLogRepository;

    /**
     * 删除鸟类记录（软删除）
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteBird(@PathVariable Long id) {
        if (!birdRepository.existsById(id)) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "鸟类记录不存在"));
        }

        // TODO: 实现软删除逻辑（设置isDeleted标志）
        // 暂时直接删除
        birdRepository.deleteById(id);

        return ResponseEntity.ok(Map.of("code", 0, "message", "删除成功"));
    }

    /**
     * 删除日志记录
     */
    @DeleteMapping("/logs/{id}")
    public ResponseEntity<Map<String, Object>> deleteLog(@PathVariable Long id) {
        if (!birdLogRepository.existsById(id)) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "日志不存在"));
        }

        birdLogRepository.deleteById(id);
        return ResponseEntity.ok(Map.of("code", 0, "message", "删除成功"));
    }

    /**
     * 鸟类统计数据
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getBirdStatistics() {
        long totalBirds = birdRepository.count();
        long totalLogs = birdLogRepository.count();

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalBirds", totalBirds);
        stats.put("totalLogs", totalLogs);
        stats.put("avgLogsPerBird", totalBirds > 0 ? String.format("%.2f", totalLogs * 1.0 / totalBirds) : "0");

        return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", stats));
    }
}
