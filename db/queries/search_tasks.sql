-- H2-compatible task search query (mirrors TaskRepository.searchTasks)
-- :term   — lower-cased, LIKE-escaped term wrapped in %, e.g. '%api%'
-- :status — status filter, or '' for all statuses
SELECT *
FROM tasks
WHERE archived = FALSE
  AND (LOWER(title) LIKE :term ESCAPE '\' OR LOWER(description) LIKE :term ESCAPE '\')
  AND (:status = '' OR status = :status)
ORDER BY created_at DESC, id DESC;
