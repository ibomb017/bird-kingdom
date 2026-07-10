package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.ParrotSpecies;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ParrotSpeciesRepository extends JpaRepository<ParrotSpecies, Integer> {

    Page<ParrotSpecies> findByCategory(String category, Pageable pageable);

    @Query("SELECT ps FROM ParrotSpecies ps WHERE LOWER(ps.name) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    Page<ParrotSpecies> searchByKeyword(String keyword, Pageable pageable);

    @Query("SELECT ps.category, COUNT(ps) FROM ParrotSpecies ps GROUP BY ps.category")
    List<Object[]> countByCategory();
}
