package com.birdkingdom.service;

import com.birdkingdom.dto.BirdDTO;
import com.birdkingdom.entity.Bird;
import com.birdkingdom.repository.BirdRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class BirdService {

    private final BirdRepository birdRepository;

    public BirdService(BirdRepository birdRepository) {
        this.birdRepository = birdRepository;
    }

    public List<BirdDTO> getAllBirds() {
        return birdRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public BirdDTO getBirdById(Long id) {
        Bird bird = birdRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + id));
        return toDTO(bird);
    }

    @Transactional
    public BirdDTO createBird(BirdDTO dto) {
        Bird bird = new Bird();
        updateEntityFromDTO(bird, dto);
        bird = birdRepository.save(bird);
        return toDTO(bird);
    }

    @Transactional
    public BirdDTO updateBird(Long id, BirdDTO dto) {
        Bird bird = birdRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + id));
        updateEntityFromDTO(bird, dto);
        bird = birdRepository.save(bird);
        return toDTO(bird);
    }

    @Transactional
    public void deleteBird(Long id) {
        Bird bird = birdRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + id));
        
        // 软删除：标记为已删除
        bird.setIsDeleted(true);
        bird.setDeletedAt(java.time.LocalDateTime.now());
        birdRepository.save(bird);
    }
    
    @Transactional
    public BirdDTO restoreBird(Long id) {
        Bird bird = birdRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + id));
        
        if (!bird.getIsDeleted()) {
            throw new RuntimeException("该鸟档案未被删除");
        }
        
        // 恢复：取消删除标记
        bird.setIsDeleted(false);
        bird.setDeletedAt(null);
        bird = birdRepository.save(bird);
        return toDTO(bird);
    }
    
    public List<BirdDTO> getDeletedBirds(Long userId) {
        return birdRepository.findByUserIdAndIsDeletedTrueOrderByDeletedAtDesc(userId)
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }
    
    public List<BirdDTO> getActiveBirds(Long userId) {
        return birdRepository.findByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(userId)
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    private BirdDTO toDTO(Bird bird) {
        BirdDTO dto = new BirdDTO();
        dto.setId(bird.getId());
        dto.setNickname(bird.getNickname());
        dto.setSpecies(bird.getSpecies());
        dto.setGender(bird.getGender());
        dto.setHatchDate(bird.getHatchDate());
        dto.setAdoptionDate(bird.getAdoptionDate());
        dto.setBirthdayType(bird.getBirthdayType());
        dto.setDeathDate(bird.getDeathDate());
        dto.setFeatherColor(bird.getFeatherColor());
        dto.setSource(bird.getSource());
        dto.setFatherInfo(bird.getFatherInfo());
        dto.setMotherInfo(bird.getMotherInfo());
        dto.setAvatarUrl(bird.getAvatarUrl());
        dto.setNotes(bird.getNotes());
        dto.setIsDeleted(bird.getIsDeleted());
        dto.setDeletedAt(bird.getDeletedAt());

        // 计算年龄 - 根据生日类型选择日期
        LocalDate birthDate = null;
        if ("ADOPTION".equals(bird.getBirthdayType()) && bird.getAdoptionDate() != null) {
            birthDate = bird.getAdoptionDate();
        } else if (bird.getHatchDate() != null) {
            birthDate = bird.getHatchDate();
        }
        
        if (birthDate != null) {
            LocalDate endDate = bird.getDeathDate() != null ? bird.getDeathDate() : LocalDate.now();
            Period period = Period.between(birthDate, endDate);
            dto.setAgeMonths(period.getYears() * 12 + period.getMonths());
        }

        return dto;
    }

    private void updateEntityFromDTO(Bird bird, BirdDTO dto) {
        bird.setNickname(dto.getNickname());
        bird.setSpecies(dto.getSpecies());
        bird.setGender(dto.getGender());
        bird.setHatchDate(dto.getHatchDate());
        bird.setAdoptionDate(dto.getAdoptionDate());
        bird.setBirthdayType(dto.getBirthdayType());
        bird.setDeathDate(dto.getDeathDate());
        bird.setFeatherColor(dto.getFeatherColor());
        bird.setSource(dto.getSource());
        bird.setFatherInfo(dto.getFatherInfo());
        bird.setMotherInfo(dto.getMotherInfo());
        bird.setAvatarUrl(dto.getAvatarUrl());
        bird.setNotes(dto.getNotes());
        if (dto.getUserId() != null) {
            bird.setUserId(dto.getUserId());
        }
    }
}
