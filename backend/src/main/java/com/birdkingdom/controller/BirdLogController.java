package com.birdkingdom.controller;

import com.birdkingdom.dto.BirdLogDTO;
import com.birdkingdom.dto.WeightTrendDTO;
import com.birdkingdom.service.BirdLogService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/logs")
@CrossOrigin(origins = "*")
public class BirdLogController {

    private final BirdLogService birdLogService;

    public BirdLogController(BirdLogService birdLogService) {
        this.birdLogService = birdLogService;
    }

    /** 获取所有日志 */
    @GetMapping
    public ResponseEntity<List<BirdLogDTO>> getAllLogs() {
        return ResponseEntity.ok(birdLogService.getAllLogs());
    }

    /** 获取某只鸟的日志 */
    @GetMapping("/bird/{birdId}")
    public ResponseEntity<List<BirdLogDTO>> getLogsByBirdId(@PathVariable Long birdId) {
        return ResponseEntity.ok(birdLogService.getLogsByBirdId(birdId));
    }

    /** 获取单条日志 */
    @GetMapping("/{id}")
    public ResponseEntity<BirdLogDTO> getLogById(@PathVariable Long id) {
        return ResponseEntity.ok(birdLogService.getLogById(id));
    }

    /** 创建日志 */
    @PostMapping
    public ResponseEntity<BirdLogDTO> createLog(@Valid @RequestBody BirdLogDTO dto) {
        return ResponseEntity.ok(birdLogService.createLog(dto));
    }

    /** 更新日志 */
    @PutMapping("/{id}")
    public ResponseEntity<BirdLogDTO> updateLog(@PathVariable Long id, @Valid @RequestBody BirdLogDTO dto) {
        return ResponseEntity.ok(birdLogService.updateLog(id, dto));
    }

    /** 删除日志 */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteLog(@PathVariable Long id) {
        birdLogService.deleteLog(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * 获取体重趋势
     * @param birdId 鸟ID（可选，不传则返回所有鸟）
     * @param range 时间范围: week, month, quarter, year
     */
    @GetMapping("/weight-trend")
    public ResponseEntity<List<WeightTrendDTO>> getWeightTrend(
            @RequestParam(required = false) Long birdId,
            @RequestParam(defaultValue = "month") String range) {
        return ResponseEntity.ok(birdLogService.getWeightTrend(birdId, range));
    }
}
