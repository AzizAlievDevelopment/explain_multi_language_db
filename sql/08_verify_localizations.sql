\echo === 1. Количество строк
SELECT 'a' AS solution,
       (SELECT count(*) FROM solution_a.entity_localizations) AS entity_loc,
       (SELECT count(*) FROM solution_a.static_localizations) AS static_loc,
       (SELECT count(*) FROM solution_a.translations)         AS translations
UNION ALL
SELECT 'b',
       (SELECT count(*) FROM solution_b.entity_localizations),
       (SELECT count(*) FROM solution_b.static_localizations),
       (SELECT count(*) FROM solution_b.translations)
UNION ALL
SELECT 'c', NULL, NULL,
       (SELECT count(*) FROM solution_c.entity_translations) + (SELECT count(*) FROM solution_c.static_translations);

\echo === 2. Разбивка по status (a / b / c) и тип ресурса
WITH a AS (
    SELECT resource_type AS kind, status, count(*) AS cnt FROM solution_a.translations GROUP BY 1, 2
), b AS (
    SELECT resource_type AS kind, status, count(*) AS cnt FROM solution_b.translations GROUP BY 1, 2
), c AS (
    SELECT 'Entity' AS kind, status, count(*) AS cnt FROM solution_c.entity_translations GROUP BY 1, 2
    UNION ALL
    SELECT 'Static', status, count(*) FROM solution_c.static_translations GROUP BY 1, 2
)
SELECT a.kind, a.status, a.cnt AS a, b.cnt AS b, c.cnt AS c,
       (a.cnt = b.cnt AND a.cnt = c.cnt) AS equal
FROM a
JOIN b USING (kind, status) JOIN c USING (kind, status)
ORDER BY a.kind, a.status;

\echo === 3. Разбивка по version и language_id (a / b / c)
WITH a AS (
    SELECT version, language_id, count(*) AS cnt FROM solution_a.translations GROUP BY 1, 2
), b AS (
    SELECT version, language_id, count(*) AS cnt FROM solution_b.translations GROUP BY 1, 2
), c AS (
    SELECT version, language_id, count(*) AS cnt FROM (
        SELECT version, language_id FROM solution_c.entity_translations
        UNION ALL
        SELECT version, language_id FROM solution_c.static_translations
    ) x GROUP BY 1, 2
)
SELECT a.version, a.language_id, a.cnt AS a, b.cnt AS b, c.cnt AS c,
       (a.cnt = b.cnt AND a.cnt = c.cnt) AS equal
FROM a
JOIN b USING (version, language_id) JOIN c USING (version, language_id)
ORDER BY 1, 2;

\echo === 4. Идентичность содержимого (все значения должны быть 0)
SELECT
  (SELECT count(*) FROM (SELECT * FROM solution_a.translations EXCEPT SELECT * FROM solution_b.translations) x) AS tr_a_minus_b,
  (SELECT count(*) FROM (SELECT * FROM solution_b.translations EXCEPT SELECT * FROM solution_a.translations) x) AS tr_b_minus_a,
  (SELECT count(*) FROM (
      SELECT id, service_code, entity_code, field_code, entity_id FROM solution_a.entity_localizations
      EXCEPT
      SELECT id,
             array_position(ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'], service_code),
             CASE entity_code WHEN 'payment_method' THEN 1 END,
             CASE field_code WHEN 'name' THEN 1 WHEN 'description' THEN 2 END,
             entity_id
      FROM solution_b.entity_localizations) x) AS entloc_a_minus_b,
  (SELECT count(*) FROM (
      SELECT id,
             array_position(ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'], service_code),
             CASE entity_code WHEN 'payment_method' THEN 1 END,
             CASE field_code WHEN 'name' THEN 1 WHEN 'description' THEN 2 END,
             entity_id
      FROM solution_b.entity_localizations
      EXCEPT
      SELECT id, service_code, entity_code, field_code, entity_id FROM solution_a.entity_localizations) x) AS entloc_b_minus_a,
  (SELECT count(*) FROM (
      SELECT id, code, service_code FROM solution_a.static_localizations
      EXCEPT
      SELECT id, substr(code, 5)::int,
             array_position(ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'], service_code)
      FROM solution_b.static_localizations) x) AS statloc_a_minus_b,
  (SELECT count(*) FROM (
      SELECT id, substr(code, 5)::int,
             array_position(ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'], service_code)
      FROM solution_b.static_localizations
      EXCEPT
      SELECT id, code, service_code FROM solution_a.static_localizations) x) AS statloc_b_minus_a;

SELECT
  (SELECT count(*) FROM (
      SELECT l.service_code, l.entity_code, l.field_code, l.entity_id, t.language_id, t.value, t.version, t.status
      FROM solution_a.translations t JOIN solution_a.entity_localizations l ON t.resource_type = 'Entity' AND t.resource_id = l.id
      EXCEPT
      SELECT service_code, entity_code, field_code, entity_id, language_id, value, version, status FROM solution_c.entity_translations) x) AS ent_a_minus_c,
  (SELECT count(*) FROM (
      SELECT service_code, entity_code, field_code, entity_id, language_id, value, version, status FROM solution_c.entity_translations
      EXCEPT
      SELECT l.service_code, l.entity_code, l.field_code, l.entity_id, t.language_id, t.value, t.version, t.status
      FROM solution_a.translations t JOIN solution_a.entity_localizations l ON t.resource_type = 'Entity' AND t.resource_id = l.id) x) AS ent_c_minus_a,
  (SELECT count(*) FROM (
      SELECT l.code, l.service_code, t.language_id, t.value, t.version, t.status
      FROM solution_a.translations t JOIN solution_a.static_localizations l ON t.resource_type = 'Static' AND t.resource_id = l.id
      EXCEPT
      SELECT code, service_code, language_id, value, version, status FROM solution_c.static_translations) x) AS stat_a_minus_c,
  (SELECT count(*) FROM (
      SELECT code, service_code, language_id, value, version, status FROM solution_c.static_translations
      EXCEPT
      SELECT l.code, l.service_code, t.language_id, t.value, t.version, t.status
      FROM solution_a.translations t JOIN solution_a.static_localizations l ON t.resource_type = 'Static' AND t.resource_id = l.id) x) AS stat_c_minus_a;

\echo === 5. Spot-check: переводы одного payment_method (pm_000123) в solution_a
SELECT l.field_code, lg.code_string, t.version, t.status, t.value
FROM solution_a.entity_localizations l
JOIN solution_a.payment_methods pm ON pm.id = l.entity_id AND pm.code = 'pm_000123'
JOIN solution_a.translations t ON t.resource_type = 'Entity' AND t.resource_id = l.id
JOIN solution_a.languages lg ON lg.id = t.language_id
ORDER BY l.field_code, t.version, lg.id;

\echo === 6. Identity сдвинут: вставка без id проходит (откат)
BEGIN;
INSERT INTO solution_a.entity_localizations (service_code, entity_code, field_code, entity_id) VALUES (9, 9, 9, gen_random_uuid()) RETURNING id;
INSERT INTO solution_b.static_localizations (code, service_code) VALUES ('key_new', 'billing') RETURNING id;
ROLLBACK;
