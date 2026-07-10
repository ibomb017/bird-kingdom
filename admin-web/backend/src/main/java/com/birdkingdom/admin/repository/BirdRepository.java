package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.Bird;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface BirdRepository extends JpaRepository<Bird, Long> {

    // 搜索鸟
    @Query("SELECT b FROM Bird b WHERE b.nickname LIKE %:keyword% OR b.species LIKE %:keyword%")
    Page<Bird> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);

    // 按品种
    Page<Bird> findBySpecies(String species, Pageable pageable);

    // 未删除的
    Page<Bird> findByIsDeletedFalse(Pageable pageable);

    // 已删除的（回收站）
    Page<Bird> findByIsDeletedTrue(Pageable pageable);

    // 走失的
    Page<Bird> findByIsLostTrue(Pageable pageable);

    // 按用户
    Page<Bird> findByUserId(Long userId, Pageable pageable);

    // 统计各品种数量
    @Query("SELECT b.species, COUNT(b) FROM Bird b WHERE b.isDeleted = false GROUP BY b.species ORDER BY COUNT(b) DESC")
    java.util.List<Object[]> countBySpecies();
}
