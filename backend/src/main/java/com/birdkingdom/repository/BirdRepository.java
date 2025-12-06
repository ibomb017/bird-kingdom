package com.birdkingdom.repository;

import com.birdkingdom.entity.Bird;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BirdRepository extends JpaRepository<Bird, Long> {

    List<Bird> findAllByOrderByCreatedAtDesc();

    List<Bird> findByNicknameContaining(String keyword);
    
    // 查询未删除的鸟儿
    List<Bird> findByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(Long userId);
    
    // 查询已删除的鸟儿（回收站）
    List<Bird> findByUserIdAndIsDeletedTrueOrderByDeletedAtDesc(Long userId);
    
    // 删除用户的所有鸟儿档案（物理删除）
    void deleteByUserId(Long userId);
}
