package com.birdkingdom.repository;

import com.birdkingdom.entity.PostComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PostCommentRepository extends JpaRepository<PostComment, Long> {
    
    // 获取帖子的评论（按时间正序）
    Page<PostComment> findByPostIdAndParentIsNullOrderByCreatedAtAsc(Long postId, Pageable pageable);
    
    // 获取评论的回复
    List<PostComment> findByParentIdOrderByCreatedAtAsc(Long parentId);
    
    // 统计帖子的评论数
    long countByPostId(Long postId);
    
    // 删除帖子的所有评论
    void deleteByPostId(Long postId);
}
