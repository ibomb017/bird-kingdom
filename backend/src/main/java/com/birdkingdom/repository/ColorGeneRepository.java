package com.birdkingdom.repository;

import com.birdkingdom.entity.ColorGene;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ColorGeneRepository extends JpaRepository<ColorGene, Long> {

    /** 按代码查询 */
    Optional<ColorGene> findByCode(String code);

    /** 按名称查询 */
    Optional<ColorGene> findByName(String name);
}
