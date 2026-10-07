CREATE OR REPLACE PACKAGE BODY task_search_pkg AS

    PROCEDURE search_tasks(
        p_search_term IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT NULL,
        p_page        IN  NUMBER   DEFAULT 1,
        p_page_size   IN  NUMBER   DEFAULT 10,
        p_results     OUT task_cursor,
        p_total_count OUT NUMBER
    ) IS
        v_term   VARCHAR2(600);
        v_page   NUMBER;
        v_size   NUMBER;
        v_offset NUMBER;
    BEGIN
        -- cap input length, escape LIKE wildcards, lower-case
        v_term := '%' || REPLACE(REPLACE(REPLACE(
                      LOWER(SUBSTR(p_search_term, 1, 255)),
                      '\', '\\'), '%', '\%'), '_', '\_') || '%';
        v_page   := GREATEST(NVL(p_page, 1), 1);
        v_size   := LEAST(GREATEST(NVL(p_page_size, 10), 1), 100);
        v_offset := (v_page - 1) * v_size;

        SELECT COUNT(*)
          INTO p_total_count
          FROM tasks
         WHERE archived = 0
           AND (LOWER(title) LIKE v_term ESCAPE '\'
                OR LOWER(description) LIKE v_term ESCAPE '\')
           AND (p_status IS NULL OR status = p_status);

        OPEN p_results FOR
            SELECT id, title, description, status, priority, assignee, created_at
              FROM (
                  SELECT t.*, ROWNUM AS rn
                    FROM (
                        SELECT id, title, description, status, priority,
                               assignee, created_at
                          FROM tasks
                         WHERE archived = 0
                           AND (LOWER(title) LIKE v_term ESCAPE '\'
                                OR LOWER(description) LIKE v_term ESCAPE '\')
                           AND (p_status IS NULL OR status = p_status)
                         ORDER BY created_at DESC, id DESC
                    ) t
                   WHERE ROWNUM <= v_offset + v_size
              )
             WHERE rn > v_offset;
    END search_tasks;

END task_search_pkg;
/
