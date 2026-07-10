package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.ForumComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ForumCommentRepository extends JpaRepository<ForumComment, Long> {

    Page<ForumComment> findByPostId(Long postId, Pageable pageable);

    Page<ForumComment> findByUserId(Long userId, Pageable pageable);
}
