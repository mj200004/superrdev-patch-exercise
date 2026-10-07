import { useState, useEffect } from 'react';
import { fetchTasks } from '../api';

export function useTasks(query, status, page, pageSize) {
  const [tasks, setTasks] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);

    fetchTasks({ query, status, page, pageSize }, controller.signal)
      .then((data) => {
        setTasks(data.items);
        setTotal(data.total);
      })
      .catch((err) => {
        if (err.name !== 'AbortError') setError(err.message);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });

    // cancel the in-flight request when inputs change or on unmount
    return () => controller.abort();
  }, [query, status, page, pageSize]);

  return { tasks, total, loading, error };
}
