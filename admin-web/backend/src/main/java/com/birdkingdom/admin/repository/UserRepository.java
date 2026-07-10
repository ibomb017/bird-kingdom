package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    // 搜索用户
    @Query("SELECT u FROM User u WHERE u.nickname LIKE %:keyword% OR u.phone LIKE %:keyword%")
    Page<User> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);

    // VIP用户
    Page<User> findByIsVipTrue(Pageable pageable);

    // 按VIP类型
    Page<User> findByVipType(String vipType, Pageable pageable);

    // 情侣VIP用户
    Page<User> findByIsCoupleVipTrue(Pageable pageable);

    // 统计今日新增
    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt >= :startOfDay")
    long countTodayNew(@Param("startOfDay") LocalDateTime startOfDay);

    // 统计VIP用户
    long countByIsVipTrue();

    // 统计情侣绑定
    long countByCouplePartnerIdNotNull();

    // 按日期范围统计新增
    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt BETWEEN :start AND :end")
    long countByCreatedAtBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    // 统计指定日期之前的用户数
    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt <= :end")
    long countByCreatedAtBefore(@Param("end") LocalDateTime end);
}
