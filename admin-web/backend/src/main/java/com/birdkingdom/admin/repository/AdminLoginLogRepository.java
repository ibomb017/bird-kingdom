package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.AdminLoginLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 管理员登录日志Repository
 */
@Repository
public interface AdminLoginLogRepository extends JpaRepository<AdminLoginLog, Long> {

    /**
     * 分页查询所有登录日志
     */
    Page<AdminLoginLog> findAllByOrderByLoginTimeDesc(Pageable pageable);

    /**
     * 根据管理员ID分页查询
     */
    Page<AdminLoginLog> findByAdminIdOrderByLoginTimeDesc(Long adminId, Pageable pageable);
}
