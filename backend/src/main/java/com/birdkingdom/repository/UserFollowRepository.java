package com.birdkingdom.repository;

import com.birdkingdom.entity.UserFollow;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserFollowRepository extends JpaRepository<UserFollow, Long> {
    
    Optional<UserFollow> findByFollowerIdAndFollowingId(Long followerId, Long followingId);
    
    boolean existsByFollowerIdAndFollowingId(Long followerId, Long followingId);
    
    void deleteByFollowerIdAndFollowingId(Long followerId, Long followingId);
    
    // 获取用户的关注列表
    Page<UserFollow> findByFollowerIdOrderByCreatedAtDesc(Long followerId, Pageable pageable);
    List<UserFollow> findByFollowerId(Long followerId);
    
    // 获取用户的粉丝列表
    Page<UserFollow> findByFollowingIdOrderByCreatedAtDesc(Long followingId, Pageable pageable);
    List<UserFollow> findByFollowingId(Long followingId);
    
    // 统计关注数
    long countByFollowerId(Long followerId);
    
    // 统计粉丝数
    long countByFollowingId(Long followingId);
    
    // 删除用户的所有关注关系
    void deleteByFollowerId(Long followerId);
    
    // 删除用户的所有粉丝关系
    void deleteByFollowingId(Long followingId);
}
