package com.birdkingdom.controller;

import com.birdkingdom.dto.*;
import com.birdkingdom.service.EncyclopediaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/encyclopedia")
@CrossOrigin(origins = "*")
public class EncyclopediaController {

    private final EncyclopediaService encyclopediaService;

    public EncyclopediaController(EncyclopediaService encyclopediaService) {
        this.encyclopediaService = encyclopediaService;
    }

    // ==================== 鸟类百科 ====================

    @GetMapping("/birds")
    public ResponseEntity<List<BirdEncyclopediaDTO>> getAllBirds() {
        return ResponseEntity.ok(encyclopediaService.getAllBirds());
    }

    @GetMapping("/birds/{id}")
    public ResponseEntity<BirdEncyclopediaDTO> getBirdById(@PathVariable Long id) {
        return ResponseEntity.ok(encyclopediaService.getBirdById(id));
    }

    @GetMapping("/birds/search")
    public ResponseEntity<List<BirdEncyclopediaDTO>> searchBirds(
            @RequestParam(required = false) String keyword) {
        return ResponseEntity.ok(encyclopediaService.searchBirds(keyword));
    }

    @GetMapping("/birds/categories")
    public ResponseEntity<List<String>> getAllCategories() {
        return ResponseEntity.ok(encyclopediaService.getAllCategories());
    }

    @GetMapping("/birds/category/{category}")
    public ResponseEntity<List<BirdEncyclopediaDTO>> getBirdsByCategory(
            @PathVariable String category) {
        return ResponseEntity.ok(encyclopediaService.getBirdsByCategory(category));
    }

    // ==================== 症状速查 ====================

    @GetMapping("/symptoms")
    public ResponseEntity<List<SymptomDTO>> getAllSymptoms() {
        return ResponseEntity.ok(encyclopediaService.getAllSymptoms());
    }

    @GetMapping("/symptoms/{id}")
    public ResponseEntity<SymptomDTO> getSymptomById(@PathVariable Long id) {
        return ResponseEntity.ok(encyclopediaService.getSymptomById(id));
    }

    @GetMapping("/symptoms/search")
    public ResponseEntity<List<SymptomDTO>> searchSymptoms(
            @RequestParam(required = false) String keyword) {
        return ResponseEntity.ok(encyclopediaService.searchSymptoms(keyword));
    }

    @GetMapping("/symptoms/severity/{severity}")
    public ResponseEntity<List<SymptomDTO>> getSymptomsBySeverity(
            @PathVariable String severity) {
        return ResponseEntity.ok(encyclopediaService.getSymptomsBySeverity(severity));
    }

    // ==================== 配色预测 ====================

    @GetMapping("/colors")
    public ResponseEntity<List<ColorGeneDTO>> getAllColorGenes() {
        return ResponseEntity.ok(encyclopediaService.getAllColorGenes());
    }

    @PostMapping("/colors/predict")
    public ResponseEntity<ColorPredictionResult> predictColor(
            @RequestBody ColorPredictionRequest request) {
        return ResponseEntity.ok(encyclopediaService.predictColor(
                request.getFatherColorCode(),
                request.getMotherColorCode()));
    }
}
