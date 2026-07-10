package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.FoodEncyclopedia;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FoodEncyclopediaRepository extends JpaRepository<FoodEncyclopedia, Long> {
    Page<FoodEncyclopedia> findByCategory(String category, Pageable pageable);

    Page<FoodEncyclopedia> findBySafetyLevel(String safetyLevel, Pageable pageable);
}
