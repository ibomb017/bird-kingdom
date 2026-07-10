package com.birdkingdom.admin.repository;

import com.birdkingdom.admin.entity.BirdLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BirdLogRepository extends JpaRepository<BirdLog, Long> {
    Page<BirdLog> findByBirdId(Long birdId, Pageable pageable);
}
