\echo === 1. Размер по таблицам (данные / индексы / всего)
SELECT n.nspname AS solution,
       c.relname AS table_name,
       c.reltuples::bigint AS rows,
       pg_size_pretty(pg_table_size(c.oid))   AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid)) AS indexes_size,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('solution_a', 'solution_b', 'solution_c')
  AND c.relkind = 'r'
  AND c.relname IN ('entity_localizations', 'static_localizations', 'translations',
                    'entity_translations', 'static_translations')
ORDER BY n.nspname, pg_total_relation_size(c.oid) DESC;

\echo === 2. Итого по решению (только таблицы локализации)
SELECT n.nspname AS solution,
       pg_size_pretty(sum(pg_table_size(c.oid)))          AS table_size,
       pg_size_pretty(sum(pg_indexes_size(c.oid)))        AS indexes_size,
       pg_size_pretty(sum(pg_total_relation_size(c.oid))) AS total_size,
       sum(pg_total_relation_size(c.oid))                 AS total_bytes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('solution_a', 'solution_b', 'solution_c')
  AND c.relkind = 'r'
  AND c.relname IN ('entity_localizations', 'static_localizations', 'translations',
                    'entity_translations', 'static_translations')
GROUP BY n.nspname
ORDER BY n.nspname;

\echo === 3. Размер каждого индекса
SELECT schemaname AS solution, tablename, indexname,
       pg_size_pretty(pg_relation_size(format('%I.%I', schemaname, indexname)::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname IN ('solution_a', 'solution_b', 'solution_c')
  AND tablename IN ('entity_localizations', 'static_localizations', 'translations',
                    'entity_translations', 'static_translations')
ORDER BY schemaname, pg_relation_size(format('%I.%I', schemaname, indexname)::regclass) DESC;
