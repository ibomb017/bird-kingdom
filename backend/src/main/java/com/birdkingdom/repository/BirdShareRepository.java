package com.birdkingdom.repository;

import com.birdkingdom.entity.BirdShare;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BirdShareRepository extends JpaRepository<BirdShare, Long> {
    
    List<BirdShare> findBySharedUserIdAndStatus(Long sharedUserId, String status);
    
    List<BirdShare> findByBirdIdAndStatus(Long birdId, String status);
    
    Optional<BirdShare> findByBirdIdAndSharedUserId(Long birdId, Long sharedUserId);
    
    boolean existsByBirdIdAndSharedUserIdAndStatus(Long birdId, Long sharedUserId, String status);
}
