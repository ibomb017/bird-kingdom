package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.ForumPost;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface ForumPostRepository extends JpaRepository<ForumPost, Long> {

    // 搜索帖子
    @Query("SELECT p FROM ForumPost p WHERE p.content LIKE %:keyword%")
    Page<ForumPost> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);

    // 按类型
    Page<ForumPost> findByPostType(String postType, Pageable pageable);

    // 按媒体类型
    Page<ForumPost> findByMediaType(String mediaType, Pageable pageable);

    // 寻鸟帖
    Page<ForumPost> findByPostTypeAndIsFoundFalse(String postType, Pageable pageable);

    // 按作者
    Page<ForumPost> findByAuthorId(Long authorId, Pageable pageable);

    // 统计今日发帖
    @Query("SELECT COUNT(p) FROM ForumPost p WHERE p.createdAt >= :startOfDay")
    long countTodayPosts(@Param("startOfDay") LocalDateTime startOfDay);

    // 按类型统计
    @Query("SELECT p.postType, COUNT(p) FROM ForumPost p GROUP BY p.postType")
    java.util.List<Object[]> countByPostType();

    // 按媒体类型统计
    @Query("SELECT p.mediaType, COUNT(p) FROM ForumPost p GROUP BY p.mediaType")
    java.util.List<Object[]> countByMediaType();

    // 按日期范围统计
    @Query("SELECT COUNT(p) FROM ForumPost p WHERE p.createdAt BETWEEN :start AND :end")
    long countByCreatedAtBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);
}
