package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.PostComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PostCommentRepository extends JpaRepository<PostComment, Long> {

    // 按帖子
    Page<PostComment> findByPostId(Long postId, Pageable pageable);

    // 按用户
    Page<PostComment> findByUserId(Long userId, Pageable pageable);

    // 按帖子删除所有评论
    void deleteByPostId(Long postId);

    // 统计帖子评论数
    long countByPostId(Long postId);
}
