package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.Symptom;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SymptomRepository extends JpaRepository<Symptom, Long> {
    Page<Symptom> findByCategory(String category, Pageable pageable);

    Page<Symptom> findBySeverity(String severity, Pageable pageable);
}
