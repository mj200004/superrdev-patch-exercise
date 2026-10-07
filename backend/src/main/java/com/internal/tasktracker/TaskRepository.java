package com.internal.tasktracker;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {

    // status = "" means "no status filter" (avoids typing issues with NULL binds)
    @Query(value = "SELECT * FROM tasks WHERE archived = FALSE "
                 + "AND (LOWER(title) LIKE :term ESCAPE '\\' OR LOWER(description) LIKE :term ESCAPE '\\') "
                 + "AND (:status = '' OR status = :status) "
                 + "ORDER BY created_at DESC, id DESC",
           countQuery = "SELECT COUNT(*) FROM tasks WHERE archived = FALSE "
                 + "AND (LOWER(title) LIKE :term ESCAPE '\\' OR LOWER(description) LIKE :term ESCAPE '\\') "
                 + "AND (:status = '' OR status = :status)",
           nativeQuery = true)
    Page<Task> searchTasks(@Param("term") String term,
                           @Param("status") String status,
                           Pageable pageable);
}
