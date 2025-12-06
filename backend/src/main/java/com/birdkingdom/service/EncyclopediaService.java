package com.birdkingdom.service;

import com.birdkingdom.dto.BirdEncyclopediaDTO;
import com.birdkingdom.dto.ColorGeneDTO;
import com.birdkingdom.dto.ColorPredictionResult;
import com.birdkingdom.dto.SymptomDTO;
import com.birdkingdom.entity.BirdEncyclopedia;
import com.birdkingdom.entity.ColorGene;
import com.birdkingdom.entity.Symptom;
import com.birdkingdom.repository.BirdEncyclopediaRepository;
import com.birdkingdom.repository.ColorGeneRepository;
import com.birdkingdom.repository.SymptomRepository;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class EncyclopediaService {

    private final BirdEncyclopediaRepository encyclopediaRepository;
    private final SymptomRepository symptomRepository;
    private final ColorGeneRepository colorGeneRepository;

    public EncyclopediaService(BirdEncyclopediaRepository encyclopediaRepository,
                               SymptomRepository symptomRepository,
                               ColorGeneRepository colorGeneRepository) {
        this.encyclopediaRepository = encyclopediaRepository;
        this.symptomRepository = symptomRepository;
        this.colorGeneRepository = colorGeneRepository;
    }

    // ==================== 鸟类百科 ====================

    public List<BirdEncyclopediaDTO> getAllBirds() {
        return encyclopediaRepository.findAll().stream()
                .map(this::toEncyclopediaDTO)
                .collect(Collectors.toList());
    }

    public BirdEncyclopediaDTO getBirdById(Long id) {
        return encyclopediaRepository.findById(id)
                .map(this::toEncyclopediaDTO)
                .orElseThrow(() -> new RuntimeException("鸟类百科不存在: " + id));
    }

    public List<BirdEncyclopediaDTO> searchBirds(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllBirds();
        }
        return encyclopediaRepository.search(keyword.trim()).stream()
                .map(this::toEncyclopediaDTO)
                .collect(Collectors.toList());
    }

    public List<String> getAllCategories() {
        return encyclopediaRepository.findAllCategories();
    }

    public List<BirdEncyclopediaDTO> getBirdsByCategory(String category) {
        return encyclopediaRepository.findByCategory(category).stream()
                .map(this::toEncyclopediaDTO)
                .collect(Collectors.toList());
    }

    private BirdEncyclopediaDTO toEncyclopediaDTO(BirdEncyclopedia entity) {
        BirdEncyclopediaDTO dto = new BirdEncyclopediaDTO();
        dto.setId(entity.getId());
        dto.setName(entity.getName());
        dto.setScientificName(entity.getScientificName());
        dto.setCategory(entity.getCategory());
        dto.setTags(parseCommaSeparated(entity.getTags()));
        dto.setDescription(entity.getDescription());
        dto.setFeedingTips(entity.getFeedingTips());
        dto.setHabitat(entity.getHabitat());
        dto.setLifespan(entity.getLifespan());
        dto.setColorHex(entity.getColorHex());
        dto.setImageUrl(entity.getImageUrl());
        return dto;
    }

    // ==================== 症状速查 ====================

    public List<SymptomDTO> getAllSymptoms() {
        return symptomRepository.findAll().stream()
                .map(this::toSymptomDTO)
                .collect(Collectors.toList());
    }

    public SymptomDTO getSymptomById(Long id) {
        return symptomRepository.findById(id)
                .map(this::toSymptomDTO)
                .orElseThrow(() -> new RuntimeException("症状不存在: " + id));
    }

    public List<SymptomDTO> searchSymptoms(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllSymptoms();
        }
        return symptomRepository.search(keyword.trim()).stream()
                .map(this::toSymptomDTO)
                .collect(Collectors.toList());
    }

    public List<SymptomDTO> getSymptomsBySeverity(String severity) {
        return symptomRepository.findBySeverity(severity).stream()
                .map(this::toSymptomDTO)
                .collect(Collectors.toList());
    }

    private SymptomDTO toSymptomDTO(Symptom entity) {
        SymptomDTO dto = new SymptomDTO();
        dto.setId(entity.getId());
        dto.setName(entity.getName());
        dto.setDescription(entity.getDescription());
        dto.setPossibleCauses(parseCommaSeparated(entity.getPossibleCauses()));
        dto.setSuggestions(parseCommaSeparated(entity.getSuggestions()));
        dto.setSeverity(entity.getSeverity());
        return dto;
    }

    // ==================== 配色预测 ====================

    public List<ColorGeneDTO> getAllColorGenes() {
        return colorGeneRepository.findAll().stream()
                .map(this::toColorGeneDTO)
                .collect(Collectors.toList());
    }

    public ColorPredictionResult predictColor(String fatherCode, String motherCode) {
        Optional<ColorGene> fatherOpt = colorGeneRepository.findByCode(fatherCode);
        Optional<ColorGene> motherOpt = colorGeneRepository.findByCode(motherCode);

        if (fatherOpt.isEmpty() || motherOpt.isEmpty()) {
            throw new RuntimeException("无效的羽色代码");
        }

        ColorGene father = fatherOpt.get();
        ColorGene mother = motherOpt.get();

        List<ColorPredictionResult.PredictedColor> predictions = new ArrayList<>();

        // 简化的遗传预测逻辑
        if (father.getCode().equals(mother.getCode())) {
            // 相同基因，100% 遗传
            predictions.add(new ColorPredictionResult.PredictedColor(
                    father.getName(), father.getDisplayColor(), 100));
        } else {
            // 不同基因，简化为各50%
            Boolean fatherDominant = father.getIsDominant();
            Boolean motherDominant = mother.getIsDominant();

            if (Boolean.TRUE.equals(fatherDominant) && !Boolean.TRUE.equals(motherDominant)) {
                predictions.add(new ColorPredictionResult.PredictedColor(
                        father.getName(), father.getDisplayColor(), 75));
                predictions.add(new ColorPredictionResult.PredictedColor(
                        mother.getName(), mother.getDisplayColor(), 25));
            } else if (!Boolean.TRUE.equals(fatherDominant) && Boolean.TRUE.equals(motherDominant)) {
                predictions.add(new ColorPredictionResult.PredictedColor(
                        mother.getName(), mother.getDisplayColor(), 75));
                predictions.add(new ColorPredictionResult.PredictedColor(
                        father.getName(), father.getDisplayColor(), 25));
            } else {
                predictions.add(new ColorPredictionResult.PredictedColor(
                        father.getName(), father.getDisplayColor(), 50));
                predictions.add(new ColorPredictionResult.PredictedColor(
                        mother.getName(), mother.getDisplayColor(), 50));
            }
        }

        return new ColorPredictionResult(predictions);
    }

    private ColorGeneDTO toColorGeneDTO(ColorGene entity) {
        ColorGeneDTO dto = new ColorGeneDTO();
        dto.setId(entity.getId());
        dto.setName(entity.getName());
        dto.setCode(entity.getCode());
        dto.setDisplayColor(entity.getDisplayColor());
        dto.setIsDominant(entity.getIsDominant());
        dto.setDescription(entity.getDescription());
        return dto;
    }

    // ==================== 工具方法 ====================

    private List<String> parseCommaSeparated(String value) {
        if (value == null || value.trim().isEmpty()) {
            return Collections.emptyList();
        }
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
    }
}
