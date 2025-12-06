package com.birdkingdom.repository;

import com.birdkingdom.entity.Symptom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SymptomRepository extends JpaRepository<Symptom, Long> {

    /** 按名称模糊搜索 */
    List<Symptom> findByNameContaining(String name);

    /** 按严重程度查询 */
    List<Symptom> findBySeverity(String severity);

    /** 搜索（名称、描述、原因） */
    @Query("SELECT s FROM Symptom s WHERE " +
           "LOWER(s.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(s.description) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "LOWER(s.possibleCauses) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    List<Symptom> search(@Param("keyword") String keyword);
}
