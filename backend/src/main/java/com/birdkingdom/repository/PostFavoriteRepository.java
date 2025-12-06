package com.birdkingdom.repository;

import com.birdkingdom.entity.PostFavorite;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PostFavoriteRepository extends JpaRepository<PostFavorite, Long> {
    
    Optional<PostFavorite> findByPostIdAndUserId(Long postId, Long userId);
    
    boolean existsByPostIdAndUserId(Long postId, Long userId);
    
    void deleteByPostIdAndUserId(Long postId, Long userId);
    
    // 获取用户收藏的帖子
    Page<PostFavorite> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
    
    List<PostFavorite> findByUserId(Long userId);
    
    long countByUserId(Long userId);
}
