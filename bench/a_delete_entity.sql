\set k random(1, 100000)
BEGIN;
WITH l AS (
    SELECT id FROM solution_a.entity_localizations
    WHERE service_code = 1 AND entity_code = 1 AND field_code IN (1, 2)
      AND entity_id = (SELECT id FROM solution_a.payment_methods WHERE code = 'pm_' || lpad(CAST(:k AS text), 6, '0'))
), del_tr AS (
    DELETE FROM solution_a.translations t USING l
    WHERE t.resource_type = 'Entity' AND t.resource_id = l.id
    RETURNING 1
)
DELETE FROM solution_a.entity_localizations e USING l WHERE e.id = l.id;
ROLLBACK;