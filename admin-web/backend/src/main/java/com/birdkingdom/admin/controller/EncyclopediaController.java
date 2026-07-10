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
 * 品种百科控制器 - 真实数据
 */
@RestController
@RequestMapping("/api/admin/encyclopedia")
public class EncyclopediaController {

        @Autowired
        private BirdEncyclopediaRepository birdEncyclopediaRepository;

        @Autowired
        private FoodEncyclopediaRepository foodEncyclopediaRepository;

        @Autowired
        private SymptomRepository symptomRepository;

        @Autowired
        private ParrotSpeciesRepository parrotSpeciesRepository;

        /**
         * 获取品种列表
         */
        @GetMapping("/species")
        public ResponseEntity<Map<String, Object>> getSpecies(
                        @RequestParam(defaultValue = "0") int page,
                        @RequestParam(defaultValue = "20") int size,
                        @RequestParam(required = false) String keyword,
                        @RequestParam(required = false) String category) {
                PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "name"));
                Page<BirdEncyclopedia> speciesPage;

                if (keyword != null && !keyword.isEmpty()) {
                        speciesPage = birdEncyclopediaRepository.searchByKeyword(keyword, pageRequest);
                } else if (category != null && !category.isEmpty()) {
                        speciesPage = birdEncyclopediaRepository.findByCategory(category, pageRequest);
                } else {
                        speciesPage = birdEncyclopediaRepository.findAll(pageRequest);
                }

                List<Map<String, Object>> species = new ArrayList<>();
                for (BirdEncyclopedia s : speciesPage.getContent()) {
                        Map<String, Object> item = new HashMap<>();
                        item.put("id", s.getId());
                        item.put("name", s.getName());
                        item.put("scientificName", s.getScientificName());
                        item.put("category", s.getCategory());
                        item.put("tags", s.getTags());
                        item.put("description", truncate(s.getDescription(), 100));
                        item.put("habitat", s.getHabitat());
                        item.put("lifespan", s.getLifespan());
                        item.put("imageUrl", s.getImageUrl());
                        item.put("priceMin", s.getPriceMin());
                        item.put("priceMax", s.getPriceMax());
                        species.add(item);
                }

                Map<String, Object> result = new HashMap<>();
                result.put("content", species);
                result.put("totalElements", speciesPage.getTotalElements());
                result.put("totalPages", speciesPage.getTotalPages());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
        }

        /**
         * 获取品种详情
         */
        @GetMapping("/species/{id}")
        public ResponseEntity<Map<String, Object>> getSpeciesDetail(@PathVariable Long id) {
                Optional<BirdEncyclopedia> opt = birdEncyclopediaRepository.findById(id);
                if (opt.isEmpty()) {
                        return ResponseEntity.ok(Map.of("code", 1, "message", "品种不存在"));
                }

                BirdEncyclopedia s = opt.get();
                Map<String, Object> detail = new HashMap<>();
                detail.put("id", s.getId());
                detail.put("name", s.getName());
                detail.put("scientificName", s.getScientificName());
                detail.put("category", s.getCategory());
                detail.put("tags", s.getTags());
                detail.put("description", s.getDescription());
                detail.put("feedingTips", s.getFeedingTips());
                detail.put("habitat", s.getHabitat());
                detail.put("lifespan", s.getLifespan());
                detail.put("imageUrl", s.getImageUrl());
                detail.put("priceMin", s.getPriceMin());
                detail.put("priceMax", s.getPriceMax());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", detail));
        }

        /**
         * 获取分类统计
         */
        @GetMapping("/species/categories")
        public ResponseEntity<Map<String, Object>> getCategories() {
                List<Object[]> stats = birdEncyclopediaRepository.countByCategory();
                List<Map<String, Object>> categories = new ArrayList<>();

                for (Object[] row : stats) {
                        categories.add(Map.of(
                                        "category", row[0] != null ? row[0] : "未分类",
                                        "count", row[1]));
                }

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", categories));
        }

        /**
         * 获取食物列表
         */
        @GetMapping("/foods")
        public ResponseEntity<Map<String, Object>> getFoods(
                        @RequestParam(defaultValue = "0") int page,
                        @RequestParam(defaultValue = "20") int size,
                        @RequestParam(required = false) String category,
                        @RequestParam(required = false) String safetyLevel) {
                PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "foodName"));
                Page<FoodEncyclopedia> foodPage;

                if (category != null && !category.isEmpty()) {
                        foodPage = foodEncyclopediaRepository.findByCategory(category, pageRequest);
                } else if (safetyLevel != null && !safetyLevel.isEmpty()) {
                        foodPage = foodEncyclopediaRepository.findBySafetyLevel(safetyLevel, pageRequest);
                } else {
                        foodPage = foodEncyclopediaRepository.findAll(pageRequest);
                }

                List<Map<String, Object>> foods = new ArrayList<>();
                for (FoodEncyclopedia f : foodPage.getContent()) {
                        Map<String, Object> item = new HashMap<>();
                        item.put("id", f.getId());
                        item.put("category", f.getCategory());
                        item.put("foodName", f.getFoodName());
                        item.put("intro", truncate(f.getIntro(), 100));
                        item.put("safetyLevel", f.getSafetyLevel());
                        item.put("status", f.getStatus());
                        foods.add(item);
                }

                Map<String, Object> result = new HashMap<>();
                result.put("content", foods);
                result.put("totalElements", foodPage.getTotalElements());
                result.put("totalPages", foodPage.getTotalPages());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
        }

        /**
         * 获取食物详情
         */
        @GetMapping("/foods/{id}")
        public ResponseEntity<Map<String, Object>> getFoodDetail(@PathVariable Long id) {
                Optional<FoodEncyclopedia> opt = foodEncyclopediaRepository.findById(id);
                if (opt.isEmpty()) {
                        return ResponseEntity.ok(Map.of("code", 1, "message", "食物不存在"));
                }

                FoodEncyclopedia f = opt.get();
                Map<String, Object> detail = new HashMap<>();
                detail.put("id", f.getId());
                detail.put("category", f.getCategory());
                detail.put("foodName", f.getFoodName());
                detail.put("intro", f.getIntro());
                detail.put("nutrition", f.getNutrition());
                detail.put("precautions", f.getPrecautions());
                detail.put("safetyLevel", f.getSafetyLevel());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", detail));
        }

        /**
         * 创建新食物
         */
        @PostMapping("/foods")
        public ResponseEntity<Map<String, Object>> createFood(@RequestBody Map<String, Object> request) {
                FoodEncyclopedia food = new FoodEncyclopedia();
                food.setCategory((String) request.get("category"));
                food.setFoodName((String) request.get("foodName"));
                food.setIntro((String) request.get("intro"));
                food.setNutrition((String) request.get("nutrition"));
                food.setPrecautions((String) request.get("precautions"));
                food.setSafetyLevel((String) request.get("safetyLevel"));
                food.setStatus(1);

                FoodEncyclopedia saved = foodEncyclopediaRepository.save(food);
                return ResponseEntity.ok(Map.of("code", 0, "message", "创建成功", "data", Map.of("id", saved.getId())));
        }

        /**
         * 更新食物
         */
        @PutMapping("/foods/{id}")
        public ResponseEntity<Map<String, Object>> updateFood(
                        @PathVariable Long id,
                        @RequestBody Map<String, Object> request) {
                Optional<FoodEncyclopedia> opt = foodEncyclopediaRepository.findById(id);
                if (opt.isEmpty()) {
                        return ResponseEntity.ok(Map.of("code", 1, "message", "食物不存在"));
                }

                FoodEncyclopedia food = opt.get();
                if (request.containsKey("category"))
                        food.setCategory((String) request.get("category"));
                if (request.containsKey("foodName"))
                        food.setFoodName((String) request.get("foodName"));
                if (request.containsKey("intro"))
                        food.setIntro((String) request.get("intro"));
                if (request.containsKey("nutrition"))
                        food.setNutrition((String) request.get("nutrition"));
                if (request.containsKey("precautions"))
                        food.setPrecautions((String) request.get("precautions"));
                if (request.containsKey("safetyLevel"))
                        food.setSafetyLevel((String) request.get("safetyLevel"));

                foodEncyclopediaRepository.save(food);
                return ResponseEntity.ok(Map.of("code", 0, "message", "更新成功"));
        }

        /**
         * 删除食物
         */
        @DeleteMapping("/foods/{id}")
        public ResponseEntity<Map<String, Object>> deleteFood(@PathVariable Long id) {
                if (!foodEncyclopediaRepository.existsById(id)) {
                        return ResponseEntity.ok(Map.of("code", 1, "message", "食物不存在"));
                }
                foodEncyclopediaRepository.deleteById(id);
                return ResponseEntity.ok(Map.of("code", 0, "message", "删除成功"));
        }

        /**
         * 获取症状列表
         */
        @GetMapping("/symptoms")
        public ResponseEntity<Map<String, Object>> getSymptoms(
                        @RequestParam(defaultValue = "0") int page,
                        @RequestParam(defaultValue = "20") int size,
                        @RequestParam(required = false) String category,
                        @RequestParam(required = false) String severity) {
                PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "name"));
                Page<Symptom> symptomPage;

                if (category != null && !category.isEmpty()) {
                        symptomPage = symptomRepository.findByCategory(category, pageRequest);
                } else if (severity != null && !severity.isEmpty()) {
                        symptomPage = symptomRepository.findBySeverity(severity, pageRequest);
                } else {
                        symptomPage = symptomRepository.findAll(pageRequest);
                }

                List<Map<String, Object>> symptoms = new ArrayList<>();
                for (Symptom s : symptomPage.getContent()) {
                        Map<String, Object> item = new HashMap<>();
                        item.put("id", s.getId());
                        item.put("name", s.getName());
                        item.put("description", truncate(s.getDescription(), 100));
                        item.put("severity", s.getSeverity());
                        item.put("category", s.getCategory());
                        symptoms.add(item);
                }

                Map<String, Object> result = new HashMap<>();
                result.put("content", symptoms);
                result.put("totalElements", symptomPage.getTotalElements());
                result.put("totalPages", symptomPage.getTotalPages());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
        }

        /**
         * 获取症状详情
         */
        @GetMapping("/symptoms/{id}")
        public ResponseEntity<Map<String, Object>> getSymptomDetail(@PathVariable Long id) {
                Optional<Symptom> opt = symptomRepository.findById(id);
                if (opt.isEmpty()) {
                        return ResponseEntity.ok(Map.of("code", 1, "message", "症状不存在"));
                }

                Symptom s = opt.get();
                Map<String, Object> detail = new HashMap<>();
                detail.put("id", s.getId());
                detail.put("name", s.getName());
                detail.put("description", s.getDescription());
                detail.put("possibleCauses", s.getPossibleCauses());
                detail.put("suggestions", s.getSuggestions());
                detail.put("whenToSeeVet", s.getWhenToSeeVet());
                detail.put("severity", s.getSeverity());
                detail.put("category", s.getCategory());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", detail));
        }

        private String truncate(String text, int maxLen) {
                if (text == null)
                        return "";
                if (text.length() <= maxLen)
                        return text;
                return text.substring(0, maxLen) + "...";
        }

        /**
         * 获取鹦鹉品种列表
         */
        @GetMapping("/parrots")
        public ResponseEntity<Map<String, Object>> getParrotSpecies(
                        @RequestParam(defaultValue = "0") int page,
                        @RequestParam(defaultValue = "20") int size,
                        @RequestParam(required = false) String category,
                        @RequestParam(required = false) String keyword) {
                PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "name"));
                Page<ParrotSpecies> parrotPage;

                if (keyword != null && !keyword.isEmpty()) {
                        parrotPage = parrotSpeciesRepository.searchByKeyword(keyword, pageRequest);
                } else if (category != null && !category.isEmpty()) {
                        parrotPage = parrotSpeciesRepository.findByCategory(category, pageRequest);
                } else {
                        parrotPage = parrotSpeciesRepository.findAll(pageRequest);
                }

                List<Map<String, Object>> parrots = new ArrayList<>();
                for (ParrotSpecies ps : parrotPage.getContent()) {
                        Map<String, Object> item = new HashMap<>();
                        item.put("id", ps.getId());
                        item.put("name", ps.getName());
                        item.put("category", ps.getCategory());
                        item.put("weightMin", ps.getWeightMin());
                        item.put("weightMax", ps.getWeightMax());
                        item.put("incubationDays", ps.getIncubationDays());
                        item.put("clutchSizeMin", ps.getClutchSizeMin());
                        item.put("clutchSizeMax", ps.getClutchSizeMax());
                        item.put("moltingDurationMin", ps.getMoltingDurationMin());
                        item.put("moltingDurationMax", ps.getMoltingDurationMax());
                        parrots.add(item);
                }

                Map<String, Object> result = new HashMap<>();
                result.put("content", parrots);
                result.put("totalElements", parrotPage.getTotalElements());
                result.put("totalPages", parrotPage.getTotalPages());

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", result));
        }

        /**
         * 获取鹦鹉品种分类统计
         */
        @GetMapping("/parrots/categories")
        public ResponseEntity<Map<String, Object>> getParrotCategories() {
                List<Object[]> stats = parrotSpeciesRepository.countByCategory();
                List<Map<String, Object>> categories = new ArrayList<>();

                for (Object[] row : stats) {
                        categories.add(Map.of(
                                        "category", row[0] != null ? row[0] : "未分类",
                                        "count", row[1]));
                }

                return ResponseEntity.ok(Map.of("code", 0, "message", "success", "data", categories));
        }
}
