package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.SplashDisplaySlot;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface SplashDisplaySlotRepository extends JpaRepository<SplashDisplaySlot, Long> {

    // 待审核
    Page<SplashDisplaySlot> findByReviewStatus(String reviewStatus, Pageable pageable);

    // 按日期
    List<SplashDisplaySlot> findByDisplayDate(LocalDate displayDate);

    // 按用户
    Page<SplashDisplaySlot> findByUserId(Long userId, Pageable pageable);

    // 按状态
    Page<SplashDisplaySlot> findByStatus(String status, Pageable pageable);

    // 统计待审核数量
    long countByReviewStatus(String reviewStatus);

    // 按日期范围统计
    @Query("SELECT s.displayDate, COUNT(s) FROM SplashDisplaySlot s WHERE s.displayDate BETWEEN :start AND :end GROUP BY s.displayDate")
    List<Object[]> countByDateRange(@Param("start") LocalDate start, @Param("end") LocalDate end);

    // 按日期和状态统计
    long countByDisplayDateAndStatus(LocalDate displayDate, String status);
}
