package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.*;
import com.birdkingdom.admin.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 百科管理扩展Controller - 补充品种和症状的CUD功能
 */
@RestController
@RequestMapping("/api/admin/encyclopedia")
public class EncyclopediaExtController {

    @Autowired
    private BirdEncyclopediaRepository birdEncyclopediaRepository;

    @Autowired
    private SymptomRepository symptomRepository;

    /**
     * 创建品种
     */
    @PostMapping("/species")
    public ResponseEntity<Map<String, Object>> createSpecies(@RequestBody Map<String, Object> request) {
        BirdEncyclopedia species = new BirdEncyclopedia();
        species.setName((String) request.get("name"));
        species.setScientificName((String) request.get("scientificName"));
        species.setCategory((String) request.get("category"));
        species.setTags((String) request.get("tags"));
        species.setDescription((String) request.get("description"));
        species.setFeedingTips((String) request.get("feedingTips"));
        species.setHabitat((String) request.get("habitat"));
        species.setLifespan((String) request.get("lifespan"));
        species.setImageUrl((String) request.get("imageUrl"));
        if (request.containsKey("priceMin"))
            species.setPriceMin((Integer) request.get("priceMin"));
        if (request.containsKey("priceMax"))
            species.setPriceMax((Integer) request.get("priceMax"));

        BirdEncyclopedia saved = birdEncyclopediaRepository.save(species);
        return ResponseEntity.ok(Map.of("code", 0, "message", "创建成功", "data", Map.of("id", saved.getId())));
    }

    /**
     * 更新品种
     */
    @PutMapping("/species/{id}")
    public ResponseEntity<Map<String, Object>> updateSpecies(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        Optional<BirdEncyclopedia> opt = birdEncyclopediaRepository.findById(id);
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "品种不存在"));
        }

        BirdEncyclopedia species = opt.get();
        if (request.containsKey("name"))
            species.setName((String) request.get("name"));
        if (request.containsKey("scientificName"))
            species.setScientificName((String) request.get("scientificName"));
        if (request.containsKey("category"))
            species.setCategory((String) request.get("category"));
        if (request.containsKey("tags"))
            species.setTags((String) request.get("tags"));
        if (request.containsKey("description"))
            species.setDescription((String) request.get("description"));
        if (request.containsKey("feedingTips"))
            species.setFeedingTips((String) request.get("feedingTips"));
        if (request.containsKey("habitat"))
            species.setHabitat((String) request.get("habitat"));
        if (request.containsKey("lifespan"))
            species.setLifespan((String) request.get("lifespan"));
        if (request.containsKey("imageUrl"))
            species.setImageUrl((String) request.get("imageUrl"));
        if (request.containsKey("priceMin"))
            species.setPriceMin((Integer) request.get("priceMin"));
        if (request.containsKey("priceMax"))
            species.setPriceMax((Integer) request.get("priceMax"));

        birdEncyclopediaRepository.save(species);
        return ResponseEntity.ok(Map.of("code", 0, "message", "更新成功"));
    }

    /**
     * 删除品种
     */
    @DeleteMapping("/species/{id}")
    public ResponseEntity<Map<String, Object>> deleteSpecies(@PathVariable Long id) {
        if (!birdEncyclopediaRepository.existsById(id)) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "品种不存在"));
        }
        birdEncyclopediaRepository.deleteById(id);
        return ResponseEntity.ok(Map.of("code", 0, "message", "删除成功"));
    }

    /**
     * 创建症状
     */
    @PostMapping("/symptoms")
    public ResponseEntity<Map<String, Object>> createSymptom(@RequestBody Map<String, Object> request) {
        Symptom symptom = new Symptom();
        symptom.setName((String) request.get("name"));
        symptom.setDescription((String) request.get("description"));
        symptom.setPossibleCauses((String) request.get("possibleCauses"));
        symptom.setSuggestions((String) request.get("suggestions"));
        symptom.setWhenToSeeVet((String) request.get("whenToSeeVet"));
        symptom.setSeverity((String) request.get("severity"));
        symptom.setCategory((String) request.get("category"));

        Symptom saved = symptomRepository.save(symptom);
        return ResponseEntity.ok(Map.of("code", 0, "message", "创建成功", "data", Map.of("id", saved.getId())));
    }

    /**
     * 更新症状
     */
    @PutMapping("/symptoms/{id}")
    public ResponseEntity<Map<String, Object>> updateSymptom(
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {
        Optional<Symptom> opt = symptomRepository.findById(id);
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "症状不存在"));
        }

        Symptom symptom = opt.get();
        if (request.containsKey("name"))
            symptom.setName((String) request.get("name"));
        if (request.containsKey("description"))
            symptom.setDescription((String) request.get("description"));
        if (request.containsKey("possibleCauses"))
            symptom.setPossibleCauses((String) request.get("possibleCauses"));
        if (request.containsKey("suggestions"))
            symptom.setSuggestions((String) request.get("suggestions"));
        if (request.containsKey("whenToSeeVet"))
            symptom.setWhenToSeeVet((String) request.get("whenToSeeVet"));
        if (request.containsKey("severity"))
            symptom.setSeverity((String) request.get("severity"));
        if (request.containsKey("category"))
            symptom.setCategory((String) request.get("category"));

        symptomRepository.save(symptom);
        return ResponseEntity.ok(Map.of("code", 0, "message", "更新成功"));
    }

    /**
     * 删除症状
     */
    @DeleteMapping("/symptoms/{id}")
    public ResponseEntity<Map<String, Object>> deleteSymptom(@PathVariable Long id) {
        if (!symptomRepository.existsById(id)) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "症状不存在"));
        }
        symptomRepository.deleteById(id);
        return ResponseEntity.ok(Map.of("code", 0, "message", "删除成功"));
    }
}
