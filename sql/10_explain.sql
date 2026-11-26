-- EXPLAIN (ANALYZE, BUFFERS) для всех сценариев и решений.
-- Каждый запрос сначала выполняется вхолостую (прогрев кэша), затем показывается план.
-- Параметры: k = 12345 (pm_012345), язык = 2, сервис статики = 3, для update k = 51 (Draft-ресурс).
\set QUIET on

\echo ############ READ_ENTITY
\o /dev/null
SELECT l.field_code, t.value FROM solution_a.entity_localizations l JOIN solution_a.translations t ON t.resource_type='Entity' AND t.resource_id=l.id WHERE l.service_code=1 AND l.entity_code=1 AND l.field_code IN (1,2) AND l.entity_id=(SELECT id FROM solution_a.payment_methods WHERE code='pm_012345') AND t.language_id=2 AND t.status='Publish' ORDER BY l.field_code;
SELECT l.field_code, t.value FROM solution_b.entity_localizations l JOIN solution_b.translations t ON t.resource_type='Entity' AND t.resource_id=l.id WHERE l.service_code='payment' AND l.entity_code='payment_method' AND l.field_code IN ('name','description') AND l.entity_id=(SELECT id FROM solution_b.payment_methods WHERE code='pm_012345') AND t.language_id=2 AND t.status='Publish' ORDER BY l.field_code;
SELECT field_code, value FROM solution_c.entity_translations WHERE service_code=1 AND entity_code=1 AND field_code IN (1,2) AND entity_id=(SELECT id FROM solution_c.payment_methods WHERE code='pm_012345') AND language_id=2 AND status='Publish' ORDER BY field_code;
\o
\echo ---- solution_a
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT l.field_code, t.value FROM solution_a.entity_localizations l JOIN solution_a.translations t ON t.resource_type='Entity' AND t.resource_id=l.id WHERE l.service_code=1 AND l.entity_code=1 AND l.field_code IN (1,2) AND l.entity_id=(SELECT id FROM solution_a.payment_methods WHERE code='pm_012345') AND t.language_id=2 AND t.status='Publish' ORDER BY l.field_code;
\echo ---- solution_b
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT l.field_code, t.value FROM solution_b.entity_localizations l JOIN solution_b.translations t ON t.resource_type='Entity' AND t.resource_id=l.id WHERE l.service_code='payment' AND l.entity_code='payment_method' AND l.field_code IN ('name','description') AND l.entity_id=(SELECT id FROM solution_b.payment_methods WHERE code='pm_012345') AND t.language_id=2 AND t.status='Publish' ORDER BY l.field_code;
\echo ---- solution_c
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT field_code, value FROM solution_c.entity_translations WHERE service_code=1 AND entity_code=1 AND field_code IN (1,2) AND entity_id=(SELECT id FROM solution_c.payment_methods WHERE code='pm_012345') AND language_id=2 AND status='Publish' ORDER BY field_code;

\echo ############ READ_STATIC
\o /dev/null
SELECT l.code, t.value FROM solution_a.static_localizations l JOIN solution_a.translations t ON t.resource_type='Static' AND t.resource_id=l.id WHERE l.service_code=3 AND t.language_id=2 AND t.status='Publish';
SELECT l.code, t.value FROM solution_b.static_localizations l JOIN solution_b.translations t ON t.resource_type='Static' AND t.resource_id=l.id WHERE l.service_code='news' AND t.language_id=2 AND t.status='Publish';
SELECT code, value FROM solution_c.static_translations WHERE service_code=3 AND language_id=2 AND status='Publish';
\o
\echo ---- solution_a
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT l.code, t.value FROM solution_a.static_localizations l JOIN solution_a.translations t ON t.resource_type='Static' AND t.resource_id=l.id WHERE l.service_code=3 AND t.language_id=2 AND t.status='Publish';
\echo ---- solution_b
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT l.code, t.value FROM solution_b.static_localizations l JOIN solution_b.translations t ON t.resource_type='Static' AND t.resource_id=l.id WHERE l.service_code='news' AND t.language_id=2 AND t.status='Publish';
\echo ---- solution_c
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT code, value FROM solution_c.static_translations WHERE service_code=3 AND language_id=2 AND status='Publish';

\echo ############ UPDATE_STATUS (в транзакции с откатом)
BEGIN;
\echo ---- solution_a
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) UPDATE solution_a.translations t SET status='Publish' FROM solution_a.entity_localizations l WHERE t.resource_type='Entity' AND t.resource_id=l.id AND l.service_code=1 AND l.entity_code=1 AND l.field_code=1 AND l.entity_id=(SELECT id FROM solution_a.payment_methods WHERE code='pm_000051') AND t.version=1;
ROLLBACK;
BEGIN;
\echo ---- solution_b
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) UPDATE solution_b.translations t SET status='Publish' FROM solution_b.entity_localizations l WHERE t.resource_type='Entity' AND t.resource_id=l.id AND l.service_code='payment' AND l.entity_code='payment_method' AND l.field_code='name' AND l.entity_id=(SELECT id FROM solution_b.payment_methods WHERE code='pm_000051') AND t.version=1;
ROLLBACK;
BEGIN;
\echo ---- solution_c
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) UPDATE solution_c.entity_translations SET status='Publish' WHERE service_code=1 AND entity_code=1 AND field_code=1 AND entity_id=(SELECT id FROM solution_c.payment_methods WHERE code='pm_000051') AND version=1;
ROLLBACK;

\echo ############ DELETE_ENTITY (в транзакции с откатом)
BEGIN;
\echo ---- solution_a
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) WITH l AS (SELECT id FROM solution_a.entity_localizations WHERE service_code=1 AND entity_code=1 AND field_code IN (1,2) AND entity_id=(SELECT id FROM solution_a.payment_methods WHERE code='pm_012345')), del_tr AS (DELETE FROM solution_a.translations t USING l WHERE t.resource_type='Entity' AND t.resource_id=l.id RETURNING 1) DELETE FROM solution_a.entity_localizations e USING l WHERE e.id=l.id;
ROLLBACK;
BEGIN;
\echo ---- solution_b
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) WITH l AS (SELECT id FROM solution_b.entity_localizations WHERE service_code='payment' AND entity_code='payment_method' AND field_code IN ('name','description') AND entity_id=(SELECT id FROM solution_b.payment_methods WHERE code='pm_012345')), del_tr AS (DELETE FROM solution_b.translations t USING l WHERE t.resource_type='Entity' AND t.resource_id=l.id RETURNING 1) DELETE FROM solution_b.entity_localizations e USING l WHERE e.id=l.id;
ROLLBACK;
BEGIN;
\echo ---- solution_c
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) DELETE FROM solution_c.entity_translations WHERE service_code=1 AND entity_code=1 AND field_code IN (1,2) AND entity_id=(SELECT id FROM solution_c.payment_methods WHERE code='pm_012345');
ROLLBACK;

\echo ############ INSERT_ENTITY (в транзакции с откатом)
BEGIN;
\echo ---- solution_a
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) WITH l AS (INSERT INTO solution_a.entity_localizations (service_code, entity_code, field_code, entity_id) VALUES (99, 1, 1, gen_random_uuid()) RETURNING id) INSERT INTO solution_a.translations (resource_id, resource_type, language_id, value, version, status) SELECT l.id, 'Entity', lg.id, 'bench value', 1, 'Draft' FROM l CROSS JOIN solution_a.languages lg;
ROLLBACK;
BEGIN;
\echo ---- solution_b
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) WITH l AS (INSERT INTO solution_b.entity_localizations (service_code, entity_code, field_code, entity_id) VALUES ('bench', 'bench', 'name', gen_random_uuid()) RETURNING id) INSERT INTO solution_b.translations (resource_id, resource_type, language_id, value, version, status) SELECT l.id, 'Entity', lg.id, 'bench value', 1, 'Draft' FROM l CROSS JOIN solution_b.languages lg;
ROLLBACK;
BEGIN;
\echo ---- solution_c
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) WITH u AS (SELECT gen_random_uuid() AS id) INSERT INTO solution_c.entity_translations (service_code, entity_code, field_code, entity_id, language_id, value, version, status) SELECT 99, 1, 1, u.id, lg.id, 'bench value', 1, 'Draft' FROM u CROSS JOIN solution_c.languages lg;
ROLLBACK;
