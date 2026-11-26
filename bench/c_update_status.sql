\set m random(0, 9999)
UPDATE solution_c.entity_translations SET status = 'Publish'
WHERE service_code = 1 AND entity_code = 1 AND field_code = 1
  AND entity_id = (SELECT id FROM solution_c.payment_methods WHERE code = 'pm_' || lpad(CAST(10 * :m + 1 AS text), 6, '0'))
  AND version = 1;