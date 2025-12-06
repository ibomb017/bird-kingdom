package com.birdkingdom.repository;

import com.birdkingdom.entity.BirdEncyclopedia;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BirdEncyclopediaRepository extends JpaRepository<BirdEncyclopedia, Long> {

    /** 按名称模糊搜索 */
    List<BirdEncyclopedia> findByNameContaining(String name);

    /** 按分类查询 */
    List<BirdEncyclopedia> findByCategory(String category);

    /** 搜索（名称、分类、标签） */
    @Query("SELECT b FROM BirdEncyclopedia b WHERE " +
           "LOWER(b.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(b.category) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(b.tags) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    List<BirdEncyclopedia> search(@Param("keyword") String keyword);

    /** 获取所有分类 */
    @Query("SELECT DISTINCT b.category FROM BirdEncyclopedia b WHERE b.category IS NOT NULL")
    List<String> findAllCategories();
}
