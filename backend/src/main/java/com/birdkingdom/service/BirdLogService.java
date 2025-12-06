package com.birdkingdom.service;

import com.birdkingdom.dto.BirdLogDTO;
import com.birdkingdom.dto.WeightTrendDTO;
import com.birdkingdom.entity.Bird;
import com.birdkingdom.entity.BirdLog;
import com.birdkingdom.repository.BirdLogRepository;
import com.birdkingdom.repository.BirdRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class BirdLogService {

    private final BirdLogRepository birdLogRepository;
    private final BirdRepository birdRepository;

    public BirdLogService(BirdLogRepository birdLogRepository, BirdRepository birdRepository) {
        this.birdLogRepository = birdLogRepository;
        this.birdRepository = birdRepository;
    }

    public List<BirdLogDTO> getAllLogs() {
        return birdLogRepository.findAllByOrderByLogDateDescCreatedAtDesc()
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<BirdLogDTO> getLogsByBirdId(Long birdId) {
        return birdLogRepository.findByBirdIdOrderByLogDateDescCreatedAtDesc(birdId)
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public BirdLogDTO getLogById(Long id) {
        BirdLog log = birdLogRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("日志不存在: " + id));
        return toDTO(log);
    }

    @Transactional
    public BirdLogDTO createLog(BirdLogDTO dto) {
        Bird bird = birdRepository.findById(dto.getBirdId())
                .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + dto.getBirdId()));

        BirdLog log = new BirdLog();
        log.setBird(bird);
        updateEntityFromDTO(log, dto);
        log = birdLogRepository.save(log);
        return toDTO(log);
    }

    @Transactional
    public BirdLogDTO updateLog(Long id, BirdLogDTO dto) {
        BirdLog log = birdLogRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("日志不存在: " + id));
        updateEntityFromDTO(log, dto);
        log = birdLogRepository.save(log);
        return toDTO(log);
    }

    @Transactional
    public void deleteLog(Long id) {
        if (!birdLogRepository.existsById(id)) {
            throw new RuntimeException("日志不存在: " + id);
        }
        birdLogRepository.deleteById(id);
    }

    /**
     * 获取体重趋势数据
     * @param birdId 鸟ID，null 表示获取所有鸟
     * @param range 时间范围: week, month, quarter, year
     */
    public List<WeightTrendDTO> getWeightTrend(Long birdId, String range) {
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = switch (range) {
            case "week" -> endDate.minusWeeks(1);
            case "month" -> endDate.minusMonths(1);
            case "quarter" -> endDate.minusMonths(3);
            case "year" -> endDate.minusYears(1);
            default -> endDate.minusMonths(1);
        };

        List<WeightTrendDTO> result = new ArrayList<>();

        if (birdId != null) {
            // 单只鸟的趋势
            Bird bird = birdRepository.findById(birdId)
                    .orElseThrow(() -> new RuntimeException("鸟档案不存在: " + birdId));

            List<BirdLog> logs = birdLogRepository.findByBirdIdAndDateRange(birdId, startDate, endDate);

            WeightTrendDTO trend = new WeightTrendDTO();
            trend.setBirdId(birdId);
            trend.setBirdName(bird.getNickname());
            trend.setPoints(logs.stream()
                    .filter(l -> l.getWeight() != null)
                    .map(l -> new WeightTrendDTO.WeightPoint(l.getLogDate(), l.getWeight()))
                    .collect(Collectors.toList()));
            result.add(trend);
        } else {
            // 所有鸟的趋势
            List<Bird> birds = birdRepository.findAll();
            for (Bird bird : birds) {
                List<BirdLog> logs = birdLogRepository.findByBirdIdAndDateRange(bird.getId(), startDate, endDate);

                WeightTrendDTO trend = new WeightTrendDTO();
                trend.setBirdId(bird.getId());
                trend.setBirdName(bird.getNickname());
                trend.setPoints(logs.stream()
                        .filter(l -> l.getWeight() != null)
                        .map(l -> new WeightTrendDTO.WeightPoint(l.getLogDate(), l.getWeight()))
                        .collect(Collectors.toList()));
                result.add(trend);
            }
        }

        return result;
    }

    private BirdLogDTO toDTO(BirdLog log) {
        BirdLogDTO dto = new BirdLogDTO();
        dto.setId(log.getId());
        dto.setBirdId(log.getBird().getId());
        dto.setBirdName(log.getBird().getNickname());
        dto.setLogDate(log.getLogDate());
        dto.setWeight(log.getWeight());
        dto.setFeedAmount(log.getFeedAmount());
        dto.setWaterAmount(log.getWaterAmount());
        dto.setMood(log.getMood());
        dto.setBehavior(log.getBehavior());
        dto.setIsMolting(log.getIsMolting());
        dto.setIsBreeding(log.getIsBreeding());
        dto.setTemperature(log.getTemperature());
        dto.setHumidity(log.getHumidity());
        dto.setIsCleaned(log.getIsCleaned());
        dto.setHealthScore(log.getHealthScore());
        dto.setNotes(log.getNotes());
        dto.setCreatedAt(log.getCreatedAt());
        return dto;
    }

    private void updateEntityFromDTO(BirdLog log, BirdLogDTO dto) {
        log.setLogDate(dto.getLogDate());
        log.setWeight(dto.getWeight());
        log.setFeedAmount(dto.getFeedAmount());
        log.setWaterAmount(dto.getWaterAmount());
        log.setMood(dto.getMood());
        log.setBehavior(dto.getBehavior());
        log.setIsMolting(dto.getIsMolting());
        log.setIsBreeding(dto.getIsBreeding());
        log.setTemperature(dto.getTemperature());
        log.setHumidity(dto.getHumidity());
        log.setIsCleaned(dto.getIsCleaned());
        log.setHealthScore(dto.getHealthScore());
        log.setNotes(dto.getNotes());
    }
}
