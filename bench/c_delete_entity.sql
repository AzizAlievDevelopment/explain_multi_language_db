\set k random(1, 100000)
BEGIN;
DELETE FROM solution_c.entity_translations
WHERE service_code = 1 AND entity_code = 1 AND field_code IN (1, 2)
  AND entity_id = (SELECT id FROM solution_c.payment_methods WHERE code = 'pm_' || lpad(CAST(:k AS text), 6, '0'));
ROLLBACK;