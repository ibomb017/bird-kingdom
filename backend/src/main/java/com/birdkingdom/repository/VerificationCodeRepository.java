package com.birdkingdom.repository;

import com.birdkingdom.entity.VerificationCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface VerificationCodeRepository extends JpaRepository<VerificationCode, Long> {
    
    Optional<VerificationCode> findTopByPhoneAndUsedFalseOrderByCreatedAtDesc(String phone);
    
    void deleteByPhone(String phone);
}
