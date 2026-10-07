# Notes

## Summary of changes
- **SQL precedence bug** (repo query, `search_tasks.sql`, Oracle package): `AND`/`OR` mixed without parentheses, so archived rows leaked into results and the status filter was ignored for title matches. Added parentheses.
- **Backend**: removed an artificial `Thread.sleep` (up to 1s on short queries); invalid `status` / `page` / `pageSize` now return 400 instead of 500; pagination moved from in-memory `subList` to DB-level `Pageable`; LIKE wildcards in user input are escaped; stable `ORDER BY` tiebreaker.
- **Frontend**: error/loading state no longer sticks forever (the `catch` never cleared loading, so errors were hidden); stale responses cancelled with `AbortController`; 300ms debounce; page resets to 1 on filter change.
- **Oracle**: same precedence fix, input length cap, page clamping.

## Not changed
- No auth, tests, or DTO layer; out of scope for a small patch.
- No full-text search or indexes; only suggested.
- Left UI styling and status label formatting alone.

## Biggest remaining risk
No authentication, and the H2 console is enabled. Also, `LIKE '%term%'` on `LOWER(...)` cannot use an index, so search will degrade as the table grows. The same filter logic is duplicated in Java, H2 SQL and Oracle PL/SQL, which is how the precedence bug appeared three times.

## Assumptions
- Invalid paging params return 400 rather than being silently clamped.
- Max page size is 100.

## Tools / AI used
Used Claude to review the code and draft the patches; I reviewed each change, ran the app and the curl checks below, and wrote the handwritten explanations myself.
