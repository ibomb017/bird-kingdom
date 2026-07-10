package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.BirdEncyclopedia;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BirdEncyclopediaRepository extends JpaRepository<BirdEncyclopedia, Long> {

    @Query("SELECT b FROM BirdEncyclopedia b WHERE b.name LIKE %:keyword% OR b.scientificName LIKE %:keyword%")
    Page<BirdEncyclopedia> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);

    Page<BirdEncyclopedia> findByCategory(String category, Pageable pageable);

    @Query("SELECT b.category, COUNT(b) FROM BirdEncyclopedia b GROUP BY b.category")
    List<Object[]> countByCategory();
}
