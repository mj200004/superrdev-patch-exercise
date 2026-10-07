Bug 1: Wrong search results



File: TaskRepository.java, search\_tasks.sql and the Oracle file (task\_search\_package.sql)



How I found it: I read the WHERE part of the query and saw AND and OR mixed with no brackets. Then I searched "api" and checked the results.



Why it happened: SQL does AND before OR, like maths does × before +. So the database read the query as "(not archived AND title matches) OR (description matches AND status matches)". The "not archived" check only worked for title matches, and the status filter only worked for description matches. So archived tasks could show up in search, and the status filter was ignored for some rows.



Before:

```sql

WHERE archived = FALSE

&#x20; AND LOWER(title) LIKE :term

&#x20;  OR LOWER(description) LIKE :term

&#x20; AND (:status IS NULL OR status = :status)

```



After:

```sql

WHERE archived = FALSE

&#x20; AND (LOWER(title) LIKE :term OR LOWER(description) LIKE :term)

&#x20; AND (:status = '' OR status = :status)

```



I put brackets around the title OR description part. I did the same in all 3 places.



\---



Bug 2: Page stuck on "Loading..." after an error



File: useTasks.js (frontend)



How I found it: I read the hook. In `.catch` it saves the error but never turns loading off. In TaskTable.jsx, loading is checked before error.



Why it happened: When a request fails, `loading` stays true forever. So the table keeps showing "Loading tasks..." and the error message never appears. Also the old error was never cleared on the next request.



Before:

```js

setLoading(true);

fetchTasks({ query, status, page, pageSize })

&#x20; .then((data) => {

&#x20;   setTasks(data.items);

&#x20;   setTotal(data.total);

&#x20;   setLoading(false);

&#x20; })

&#x20; .catch((err) => {

&#x20;   setError(err.message);

&#x20; });

```



After:

```js

setLoading(true);

setError(null);

fetchTasks(...)

&#x20; .then((data) => {

&#x20;   setTasks(data.items);

&#x20;   setTotal(data.total);

&#x20; })

&#x20; .catch((err) => {

&#x20;   if (err.name !== 'AbortError') setError(err.message);

&#x20; })

&#x20; .finally(() => {

&#x20;   if (!controller.signal.aborted) setLoading(false);

&#x20; });

```



`.finally` runs both on success and on failure, so loading always turns off. I also clear the old error at the start of each request.



\---



Bug 3: Old results can replace new results



File: useTasks.js and api.js (frontend)



How I found it: I read the useEffect and saw there was no cleanup. Every key press sends a request, so I asked what happens if the replies come back in a different order.



Why it happened: This is a race condition. If I type "ap" and then "api", two requests go out. If the "ap" reply is slow and comes last, the screen shows the "ap" results while the box says "api". The wrong answer wins.



Before:

```js

// api.js

const response = await fetch(url);



// useTasks.js

useEffect(() => {

&#x20; setLoading(true);

&#x20; fetchTasks({ query, status, page, pageSize }).then(...)

}, \[query, status, page, pageSize]);

```



After:

```js

// api.js

export async function fetchTasks({ ... }, signal) {

&#x20; const response = await fetch(url, { signal });



// useTasks.js

useEffect(() => {

&#x20; const controller = new AbortController();

&#x20; fetchTasks({ query, status, page, pageSize }, controller.signal)...

&#x20; return () => controller.abort();

}, \[query, status, page, pageSize]);

```



Each request can now be cancelled. When the search changes, the cleanup cancels the old request. A cancelled request gives an AbortError, which is expected, so I ignore it.



\---



Bug 4: Fake delay in the controller



File: TaskController.java (backend)



How I found it: I read the controller. The comment said "for logging", but the code actually sleeps. Logging should never make a request wait.



Why it happened: The code sleeps for (10 − search length) × 100 milliseconds. An empty search waits 1 second. Short searches are slower than long ones, which makes no sense. Sleeping also keeps a server thread busy doing nothing.



Before:

```java

int complexityScore = Math.max(0, 10 - query.length());

long queryWeight = complexityScore \* 100L;

try {

&#x20;   Thread.sleep(queryWeight);

} catch (InterruptedException e) {

&#x20;   Thread.currentThread().interrupt();

}

```



After:

```java

// deleted. Only a log line is left:

log.debug("search qLen={} status={} page={} pageSize={}",

&#x20;         query.length(), statusFilter, page, pageSize);

```



I deleted the sleep completely.



\---



Bug 5: Server error 500 on bad input



File: TaskController.java (backend)



How I found it: I read the code and asked what happens if the user sends something wrong. `TaskStatus.valueOf("BOGUS")` throws an error. And `page=0` makes the start index negative, which crashes `subList`.



Why it happened: There was no checking of the input. A mistake by the user turned into a server crash (500). A 500 means "server is broken", but here the user made the mistake, so it should be 400.



Before:

```java

String normalizedStatus = null;

if (status != null \&\& !status.isEmpty()) {

&#x20;   normalizedStatus = TaskStatus.valueOf(status.toUpperCase()).name();

}

...

int start = (page - 1) \* pageSize;

```



After:

```java

if (page < 1 || pageSize < 1 || pageSize > MAX\_PAGE\_SIZE) {

&#x20;   throw new ResponseStatusException(HttpStatus.BAD\_REQUEST,

&#x20;       "page must be >= 1 and pageSize must be 1.." + MAX\_PAGE\_SIZE);

}



String statusFilter = "";

if (status != null \&\& !status.isBlank()) {

&#x20;   try {

&#x20;       statusFilter = TaskStatus.valueOf(status.trim().toUpperCase()).name();

&#x20;   } catch (IllegalArgumentException e) {

&#x20;       throw new ResponseStatusException(HttpStatus.BAD\_REQUEST, "Invalid status: " + status);

&#x20;   }

}

```



Now wrong input gives 400. I also limited pageSize to 100 so nobody can ask for a million rows. I tested status=BOGUS and page=0 and both gave HTTP 400.



\---



Bug 6: Server loaded every row to show one page



File: TaskController.java and TaskRepository.java (backend)



How I found it: I read the repository. It returns a List of all matching rows, and then the controller cuts out the page using `subList`. The database did not know about pages at all.



Why it happened: With 49 tasks you don't notice. With 100,000 tasks, every click on Next would load all 100,000 rows into memory just to show 10. The database should do the cutting.



Before:

```java

List<Task> allResults = taskRepository.searchTasks(searchTerm, normalizedStatus);



int start = (page - 1) \* pageSize;

int end = Math.min(start + pageSize, allResults.size());

List<Task> pageResults = (start < allResults.size())

&#x20;       ? allResults.subList(start, end)

&#x20;       : Collections.emptyList();



response.put("total", allResults.size());

```



After:

```java

// TaskRepository.java

Page<Task> searchTasks(@Param("term") String term,

&#x20;                      @Param("status") String status,

&#x20;                      Pageable pageable);

// plus a countQuery to count the total matches



// TaskController.java

Page<Task> result = taskRepository.searchTasks(term, statusFilter,

&#x20;                       PageRequest.of(page - 1, pageSize));

response.put("items", result.getContent());

response.put("total", result.getTotalElements());

```



Now the database returns only the 10 rows of that page. The count query gives the total so the screen can still show "Page 1 of 5". I use `page - 1` because Spring starts pages from 0 and the website starts from 1.



\---



Bug 7: Empty page after changing the search or filter



File: App.jsx (frontend)



How I found it: I thought about how a user uses it. Go to page 3, then type a search. The search may have only 1 page of results, but the page number still says 3.



Why it happened: page, query and status were three separate values. Changing the search did not change the page. So the app asked the server for page 3 of a result that has only 1 page, and showed "No tasks found" even though results exist.



Before:

```jsx

<SearchBar value={query} onChange={setQuery} />

<StatusFilter value={status} onChange={setStatus} />

```



After:

```jsx

const handleQueryChange = (v) => { setQuery(v); setPage(1); };

const handleStatusChange = (v) => { setStatus(v); setPage(1); };



<SearchBar value={query} onChange={handleQueryChange} />

<StatusFilter value={status} onChange={handleStatusChange} />

```



Now whenever the search or the status changes, the page goes back to 1.



\---



Bug 8: A request on every key press



File: App.jsx and a new file hooks/useDebounce.js (frontend)



How I found it: I read App.jsx. The search text goes straight into useTasks, and useTasks runs again whenever the text changes. So every letter sends a request.



Why it happened: Typing "api" sends 3 requests ("a", "ap", "api"). That wastes server work and makes Bug 3 more likely. The user only needs the result for the final text.



Before:

```jsx

const { tasks, total, loading, error } = useTasks(query, status, page, 10);

```



After:

```jsx

// new file: hooks/useDebounce.js

export function useDebounce(value, delay = 300) {

&#x20; const \[debounced, setDebounced] = useState(value);

&#x20; useEffect(() => {

&#x20;   const id = setTimeout(() => setDebounced(value), delay);

&#x20;   return () => clearTimeout(id);

&#x20; }, \[value, delay]);

&#x20; return debounced;

}



// App.jsx

const debouncedQuery = useDebounce(query.trim(), 300);

const { tasks, total, loading, error } = useTasks(debouncedQuery, status, page, PAGE\_SIZE);

```



The search box still updates instantly, but the request is sent only after the user stops typing for 300 ms. If another key is pressed before that, the old timer is cleared, so only the last one runs.

