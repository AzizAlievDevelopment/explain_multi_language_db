\timing on
BEGIN;

TRUNCATE solution_a.entity_localizations, solution_a.static_localizations, solution_a.translations RESTART IDENTITY;
TRUNCATE solution_b.entity_localizations, solution_b.static_localizations, solution_b.translations RESTART IDENTITY;
TRUNCATE solution_c.entity_translations, solution_c.static_translations RESTART IDENTITY;

-- ---------------------------------------------------------------------------
-- Staging: весь набор данных генерируется ОДИН раз и детерминированно (без random()),
-- затем раскладывается в три решения.
-- ---------------------------------------------------------------------------

-- Entity-ресурсы: по 2 поля (1 = name, 2 = description) на каждый payment_method
CREATE TEMP TABLE stage_entity ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY pm.code, f.field_code)::int AS id,
       1            AS service_code,   -- 1 = payment
       1            AS entity_code,    -- 1 = payment_method
       f.field_code AS field_code,     -- 1 = name, 2 = description
       pm.id        AS entity_id,
       pm.code      AS pm_code
FROM solution_a.payment_methods pm
CROSS JOIN (VALUES (1), (2)) AS f(field_code);

-- Static-ресурсы: 10 сервисов x 1000 ключей
CREATE TEMP TABLE stage_static ON COMMIT DROP AS
SELECT i                  AS id,
       (i - 1) / 1000 + 1 AS service_code,
       (i - 1) % 1000 + 1 AS code
FROM generate_series(1, 10000) AS i;

-- Тексты по языкам
CREATE TEMP TABLE stage_text ON COMMIT DROP AS
SELECT l.id AS language_id, x.entity_prefix, x.name_word, x.desc_word, x.static_prefix
FROM solution_a.languages l
JOIN (VALUES
    ('en', 'Payment method',  'name',     'description', 'Static text'),
    ('ru', 'Способ оплаты',   'название', 'описание',    'Статический текст'),
    ('tg', 'Усули пардохт',   'ном',      'тавсиф',      'Матни статикӣ'),
    ('uz', 'Toʻlov usuli',    'nomi',     'tavsif',      'Statik matn')
) AS x(code_string, entity_prefix, name_word, desc_word, static_prefix)
  ON x.code_string = l.code_string;

-- Версии и статусы на уровне ресурса (детерминированно от id):
--   id % 5 = 0  -> v1 = Archive, v2 = Publish
--   иначе v1: id % 20 = 1 Draft, 2 Pending, 3 Cancel, остальные Publish
CREATE TEMP TABLE stage_versions ON COMMIT DROP AS
SELECT 'Entity'::varchar(10) AS resource_type, e.id AS resource_id, v.version, v.status
FROM stage_entity e
CROSS JOIN LATERAL (VALUES
    (1, CASE WHEN e.id % 5 = 0  THEN 'Archive'
             WHEN e.id % 20 = 1 THEN 'Draft'
             WHEN e.id % 20 = 2 THEN 'Pending'
             WHEN e.id % 20 = 3 THEN 'Cancel'
             ELSE 'Publish' END),
    (2, 'Publish')
) AS v(version, status)
WHERE v.version = 1 OR e.id % 5 = 0
UNION ALL
SELECT 'Static', s.id, v.version, v.status
FROM stage_static s
CROSS JOIN LATERAL (VALUES
    (1, CASE WHEN s.id % 5 = 0  THEN 'Archive'
             WHEN s.id % 20 = 1 THEN 'Draft'
             WHEN s.id % 20 = 2 THEN 'Pending'
             WHEN s.id % 20 = 3 THEN 'Cancel'
             ELSE 'Publish' END),
    (2, 'Publish')
) AS v(version, status)
WHERE v.version = 1 OR s.id % 5 = 0;

-- Переводы = версии ресурса x 4 языка
CREATE TEMP TABLE stage_translations ON COMMIT DROP AS
SELECT v.resource_type,
       v.resource_id,
       t.language_id,
       CASE v.resource_type
           WHEN 'Entity' THEN t.entity_prefix || ' ' || e.pm_code || ' — '
                              || CASE e.field_code WHEN 1 THEN t.name_word ELSE t.desc_word END
           ELSE               t.static_prefix || ' ' || s.service_code || '.' || lpad(s.code::text, 4, '0')
       END || CASE WHEN v.version = 2 THEN ' (v2)' ELSE '' END AS value,
       v.version,
       v.status
FROM stage_versions v
CROSS JOIN stage_text t
LEFT JOIN stage_entity e ON v.resource_type = 'Entity' AND e.id = v.resource_id
LEFT JOIN stage_static s ON v.resource_type = 'Static' AND s.id = v.resource_id;

-- ---------------------------------------------------------------------------
-- solution_a (коды INT)
-- ---------------------------------------------------------------------------
INSERT INTO solution_a.entity_localizations (id, service_code, entity_code, field_code, entity_id)
OVERRIDING SYSTEM VALUE
SELECT id, service_code, entity_code, field_code, entity_id FROM stage_entity ORDER BY id;

INSERT INTO solution_a.static_localizations (id, code, service_code)
OVERRIDING SYSTEM VALUE
SELECT id, code, service_code FROM stage_static ORDER BY id;

INSERT INTO solution_a.translations (resource_id, resource_type, language_id, value, version, status)
SELECT resource_id, resource_type, language_id, value, version, status
FROM stage_translations
ORDER BY resource_type, resource_id, language_id, version;

-- ---------------------------------------------------------------------------
-- solution_b (коды VARCHAR; те же id, коды переведены в строки)
-- ---------------------------------------------------------------------------
INSERT INTO solution_b.entity_localizations (id, service_code, entity_code, field_code, entity_id)
OVERRIDING SYSTEM VALUE
SELECT id,
       (ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'])[service_code],
       CASE entity_code WHEN 1 THEN 'payment_method' END,
       CASE field_code WHEN 1 THEN 'name' WHEN 2 THEN 'description' END,
       entity_id
FROM stage_entity ORDER BY id;

INSERT INTO solution_b.static_localizations (id, code, service_code)
OVERRIDING SYSTEM VALUE
SELECT id,
       'key_' || lpad(code::text, 4, '0'),
       (ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'])[service_code]
FROM stage_static ORDER BY id;

INSERT INTO solution_b.translations (resource_id, resource_type, language_id, value, version, status)
SELECT resource_id, resource_type, language_id, value, version, status
FROM stage_translations
ORDER BY resource_type, resource_id, language_id, version;

-- ---------------------------------------------------------------------------
-- solution_c (денормализовано: коды встроены в строки переводов)
-- ---------------------------------------------------------------------------
INSERT INTO solution_c.entity_translations
    (service_code, entity_code, field_code, entity_id, language_id, value, version, status)
SELECT e.service_code, e.entity_code, e.field_code, e.entity_id, t.language_id, t.value, t.version, t.status
FROM stage_translations t
JOIN stage_entity e ON t.resource_type = 'Entity' AND e.id = t.resource_id
ORDER BY e.id, t.language_id, t.version;

INSERT INTO solution_c.static_translations
    (code, service_code, language_id, value, version, status)
SELECT s.code, s.service_code, t.language_id, t.value, t.version, t.status
FROM stage_translations t
JOIN stage_static s ON t.resource_type = 'Static' AND s.id = t.resource_id
ORDER BY s.id, t.language_id, t.version;

-- identity-последовательности: после вставки с явными id сдвигаем на max(id),
-- чтобы следующая вставка без id не упёрлась в дубликат
SELECT setval(pg_get_serial_sequence('solution_a.entity_localizations', 'id'), (SELECT max(id) FROM solution_a.entity_localizations));
SELECT setval(pg_get_serial_sequence('solution_a.static_localizations', 'id'), (SELECT max(id) FROM solution_a.static_localizations));
SELECT setval(pg_get_serial_sequence('solution_b.entity_localizations', 'id'), (SELECT max(id) FROM solution_b.entity_localizations));
SELECT setval(pg_get_serial_sequence('solution_b.static_localizations', 'id'), (SELECT max(id) FROM solution_b.static_localizations));

COMMIT;

ANALYZE solution_a.entity_localizations;
ANALYZE solution_a.static_localizations;
ANALYZE solution_a.translations;
ANALYZE solution_b.entity_localizations;
ANALYZE solution_b.static_localizations;
ANALYZE solution_b.translations;
ANALYZE solution_c.entity_translations;
ANALYZE solution_c.static_translations;
