package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.UserNotification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 用户通知Repository
 */
@Repository
public interface UserNotificationRepository extends JpaRepository<UserNotification, Long> {
    /**
     * 查询用户的未读通知数量
     */
    long countByUserIdAndIsReadFalse(Long userId);
}
