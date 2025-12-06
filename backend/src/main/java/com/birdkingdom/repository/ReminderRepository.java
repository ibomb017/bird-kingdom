package com.birdkingdom.repository;

import com.birdkingdom.entity.Reminder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReminderRepository extends JpaRepository<Reminder, Long> {

    List<Reminder> findAllByOrderByCreatedAtDesc();

    List<Reminder> findByEnabledTrue();

    List<Reminder> findByBirdId(Long birdId);
}
