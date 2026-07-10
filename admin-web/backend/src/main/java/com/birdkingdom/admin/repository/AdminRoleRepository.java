package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.AdminRole;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * 管理员角色Repository
 */
@Repository
public interface AdminRoleRepository extends JpaRepository<AdminRole, Long> {

    /**
     * 根据角色代码查找
     */
    Optional<AdminRole> findByRoleCode(String roleCode);
}
