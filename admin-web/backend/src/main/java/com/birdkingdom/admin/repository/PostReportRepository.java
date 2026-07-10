package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.PostReport;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PostReportRepository extends JpaRepository<PostReport, Long> {

    // 按状态
    Page<PostReport> findByStatus(String status, Pageable pageable);

    // 统计待处理
    long countByStatus(String status);
}
