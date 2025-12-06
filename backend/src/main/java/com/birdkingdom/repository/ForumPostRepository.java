package com.birdkingdom.repository;

import com.birdkingdom.entity.ForumPost;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ForumPostRepository extends JpaRepository<ForumPost, Long> {
    
    // 按时间倒序获取帖子
    Page<ForumPost> findAllByOrderByCreatedAtDesc(Pageable pageable);
    
    // 获取用户的帖子
    Page<ForumPost> findByAuthorIdOrderByCreatedAtDesc(Long authorId, Pageable pageable);
    
    // 按类型获取帖子
    Page<ForumPost> findByPostTypeOrderByCreatedAtDesc(String postType, Pageable pageable);
    
    // 搜索帖子
    @Query("SELECT p FROM ForumPost p WHERE p.content LIKE %:keyword% ORDER BY p.createdAt DESC")
    Page<ForumPost> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);
    
    // 获取附近的帖子（简单距离计算）
    @Query("SELECT p FROM ForumPost p WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL " +
           "AND ABS(p.latitude - :lat) < :range AND ABS(p.longitude - :lng) < :range " +
           "ORDER BY p.createdAt DESC")
    Page<ForumPost> findNearby(@Param("lat") Double latitude, @Param("lng") Double longitude, 
                               @Param("range") Double range, Pageable pageable);
    
    // 获取寻鸟帖子
    List<ForumPost> findByPostTypeAndIsFoundFalseOrderByCreatedAtDesc(String postType);
    
    // 删除用户的所有帖子
    void deleteByAuthorId(Long authorId);
}
