package com.birdkingdom.repository;

import com.birdkingdom.entity.BirdLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface BirdLogRepository extends JpaRepository<BirdLog, Long> {

    /** 按时间倒序获取所有日志 */
    List<BirdLog> findAllByOrderByLogDateDescCreatedAtDesc();

    /** 获取某只鸟的所有日志 */
    List<BirdLog> findByBirdIdOrderByLogDateDescCreatedAtDesc(Long birdId);

    /** 获取某只鸟某天的日志 */
    Optional<BirdLog> findByBirdIdAndLogDate(Long birdId, LocalDate logDate);

    /** 获取某只鸟在指定日期范围内的日志（用于体重趋势） */
    @Query("SELECT l FROM BirdLog l WHERE l.bird.id = :birdId AND l.logDate BETWEEN :startDate AND :endDate ORDER BY l.logDate ASC")
    List<BirdLog> findByBirdIdAndDateRange(
            @Param("birdId") Long birdId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate
    );

    /** 获取所有鸟在指定日期范围内的日志 */
    @Query("SELECT l FROM BirdLog l WHERE l.logDate BETWEEN :startDate AND :endDate ORDER BY l.logDate ASC")
    List<BirdLog> findByDateRange(
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate
    );
}
