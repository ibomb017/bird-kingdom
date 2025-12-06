package com.birdkingdom.repository;

import com.birdkingdom.entity.PostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PostLikeRepository extends JpaRepository<PostLike, Long> {
    
    Optional<PostLike> findByPostIdAndUserId(Long postId, Long userId);
    
    boolean existsByPostIdAndUserId(Long postId, Long userId);
    
    void deleteByPostIdAndUserId(Long postId, Long userId);
    
    long countByPostId(Long postId);
    
    // 获取用户点赞的帖子ID列表
    List<PostLike> findByUserId(Long userId);
}
