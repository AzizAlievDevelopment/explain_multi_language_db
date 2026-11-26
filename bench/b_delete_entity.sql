\set k random(1, 100000)
BEGIN;
WITH l AS (
    SELECT id FROM solution_b.entity_localizations
    WHERE service_code = 'payment' AND entity_code = 'payment_method' AND field_code IN ('name', 'description')
      AND entity_id = (SELECT id FROM solution_b.payment_methods WHERE code = 'pm_' || lpad(CAST(:k AS text), 6, '0'))
), del_tr AS (
    DELETE FROM solution_b.translations t USING l
    WHERE t.resource_type = 'Entity' AND t.resource_id = l.id
    RETURNING 1
)
DELETE FROM solution_b.entity_localizations e USING l WHERE e.id = l.id;
ROLLBACK;