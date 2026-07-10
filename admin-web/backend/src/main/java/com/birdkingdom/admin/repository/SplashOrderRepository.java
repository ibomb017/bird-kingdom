package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.SplashOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Repository
public interface SplashOrderRepository extends JpaRepository<SplashOrder, Long> {

    Page<SplashOrder> findByUserId(Long userId, Pageable pageable);

    Page<SplashOrder> findByStatus(String status, Pageable pageable);

    @Query("SELECT SUM(o.amount) FROM SplashOrder o WHERE o.status = 'PAID'")
    BigDecimal getTotalPaidAmount();

    @Query("SELECT SUM(o.amount) FROM SplashOrder o WHERE o.status = 'PAID' AND o.paidAt >= :start")
    BigDecimal getPaidAmountSince(@Param("start") java.time.LocalDateTime start);

    long countByStatus(String status);

    @Query("SELECT SUM(o.amount) FROM SplashOrder o WHERE o.status = 'PAID' AND o.displayDate = :date")
    Double sumAmountByDate(@Param("date") LocalDate date);
}
