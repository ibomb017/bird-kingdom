package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.UserActivityLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

/**
 * 用户活跃度记录Repository
 */
@Repository
public interface UserActivityLogRepository extends JpaRepository<UserActivityLog, Long> {

    /**
     * 根据用户ID和日期查找
     */
    Optional<UserActivityLog> findByUserIdAndActivityDate(Long userId, LocalDate activityDate);

    /**
     * 统计指定日期的活跃用户数
     */
    @Query("SELECT COUNT(DISTINCT u.userId) FROM UserActivityLog u WHERE u.activityDate = :date")
    long countActiveUsersByDate(@Param("date") LocalDate date);

    /**
     * 统计指定日期范围内的活跃用户数
     */
    @Query("SELECT COUNT(DISTINCT u.userId) FROM UserActivityLog u WHERE u.activityDate BETWEEN :startDate AND :endDate")
    long countActiveUsersBetweenDates(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate);

    /**
     * 统计指定日期的去重活跃用户数（用于每日活跃统计）
     * 根据 activityDate 字段来查询，它是DATE类型
     */
    @Query("SELECT COUNT(DISTINCT u.userId) FROM UserActivityLog u WHERE u.activityDate = :activityDate")
    long countDistinctUsersByActivityDate(@Param("activityDate") LocalDate activityDate);
}
