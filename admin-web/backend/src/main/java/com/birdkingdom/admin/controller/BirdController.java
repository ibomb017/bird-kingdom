package com.birdkingdom.admin.controller;

import com.birdkingdom.admin.entity.Bird;
import com.birdkingdom.admin.entity.User;
import com.birdkingdom.admin.repository.BirdRepository;
import com.birdkingdom.admin.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 鸟舍管理控制器 - 真实数据
 */
@RestController
@RequestMapping("/api/admin/birds")
public class BirdController {

    @Autowired
    private BirdRepository birdRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * 获取鸟档案列表
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getBirds(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String species,
            @RequestParam(required = false) String status) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Bird> birdPage;

        if (keyword != null && !keyword.isEmpty()) {
            birdPage = birdRepository.searchByKeyword(keyword, pageRequest);
        } else if (species != null && !species.isEmpty()) {
            birdPage = birdRepository.findBySpecies(species, pageRequest);
        } else if ("deleted".equals(status)) {
            birdPage = birdRepository.findByIsDeletedTrue(pageRequest);
        } else if ("lost".equals(status)) {
            birdPage = birdRepository.findByIsLostTrue(pageRequest);
        } else {
            birdPage = birdRepository.findByIsDeletedFalse(pageRequest);
        }

        List<Map<String, Object>> birds = new ArrayList<>();
        for (Bird bird : birdPage.getContent()) {
            Map<String, Object> birdMap = new HashMap<>();
            birdMap.put("id", bird.getId());
            birdMap.put("nickname", bird.getNickname());
            birdMap.put("species", bird.getSpecies());
            birdMap.put("gender", bird.getGender());
            birdMap.put("featherColor", bird.getFeatherColor());
            birdMap.put("hatchDate", bird.getHatchDate());
            birdMap.put("avatarUrl", bird.getAvatarUrl());
            birdMap.put("isDeleted", bird.getIsDeleted());
            birdMap.put("isLost", bird.getIsLost());
            birdMap.put("userId", bird.getUserId());
            birdMap.put("createdAt", bird.getCreatedAt());

            // 获取主人信息
            if (bird.getUserId() != null) {
                userRepository.findById(bird.getUserId()).ifPresent(owner -> {
                    birdMap.put("ownerNickname", owner.getNickname());
                    birdMap.put("ownerAvatarUrl", owner.getAvatarUrl());
                });
            }

            birds.add(birdMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", birds);
        result.put("totalElements", birdPage.getTotalElements());
        result.put("totalPages", birdPage.getTotalPages());
        result.put("number", birdPage.getNumber());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 获取鸟详情
     */
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getBirdDetail(@PathVariable Long id) {
        Optional<Bird> birdOpt = birdRepository.findById(id);
        if (birdOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 1, "message", "鸟档案不存在"));
        }

        Bird bird = birdOpt.get();
        Map<String, Object> detail = new HashMap<>();
        detail.put("id", bird.getId());
        detail.put("nickname", bird.getNickname());
        detail.put("species", bird.getSpecies());
        detail.put("gender", bird.getGender());
        detail.put("featherColor", bird.getFeatherColor());
        detail.put("hatchDate", bird.getHatchDate());
        detail.put("adoptionDate", bird.getAdoptionDate());
        detail.put("avatarUrl", bird.getAvatarUrl());
        detail.put("isDeleted", bird.getIsDeleted());
        detail.put("isLost", bird.getIsLost());
        detail.put("userId", bird.getUserId());
        detail.put("createdAt", bird.getCreatedAt());

        // 获取主人信息
        if (bird.getUserId() != null) {
            userRepository.findById(bird.getUserId()).ifPresent(owner -> {
                detail.put("ownerNickname", owner.getNickname());
                detail.put("ownerAvatarUrl", owner.getAvatarUrl());
                detail.put("ownerPhone", maskPhone(owner.getPhone()));
            });
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", detail));
    }

    /**
     * 获取品种统计
     */
    @GetMapping("/species-stats")
    public ResponseEntity<Map<String, Object>> getSpeciesStats() {
        List<Object[]> stats = birdRepository.countBySpecies();
        List<Map<String, Object>> result = new ArrayList<>();

        for (Object[] row : stats) {
            result.add(Map.of(
                    "species", row[0],
                    "count", row[1]));
        }

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    /**
     * 获取回收站列表
     */
    @GetMapping("/trash")
    public ResponseEntity<Map<String, Object>> getTrash(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "updatedAt"));
        Page<Bird> birdPage = birdRepository.findByIsDeletedTrue(pageRequest);

        List<Map<String, Object>> birds = new ArrayList<>();
        for (Bird bird : birdPage.getContent()) {
            Map<String, Object> birdMap = new HashMap<>();
            birdMap.put("id", bird.getId());
            birdMap.put("nickname", bird.getNickname());
            birdMap.put("species", bird.getSpecies());
            birdMap.put("avatarUrl", bird.getAvatarUrl());
            birdMap.put("userId", bird.getUserId());
            birdMap.put("createdAt", bird.getCreatedAt());
            birdMap.put("updatedAt", bird.getUpdatedAt());
            birds.add(birdMap);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("content", birds);
        result.put("totalElements", birdPage.getTotalElements());
        result.put("totalPages", birdPage.getTotalPages());

        return ResponseEntity.ok(Map.of(
                "code", 0,
                "message", "success",
                "data", result));
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7)
            return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }
}
