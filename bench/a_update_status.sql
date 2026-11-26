\set m random(0, 9999)
UPDATE solution_a.translations t SET status = 'Publish'
FROM solution_a.entity_localizations l
WHERE t.resource_type = 'Entity' AND t.resource_id = l.id
  AND l.service_code = 1 AND l.entity_code = 1 AND l.field_code = 1
  AND l.entity_id = (SELECT id FROM solution_a.payment_methods WHERE code = 'pm_' || lpad(CAST(10 * :m + 1 AS text), 6, '0'))
  AND t.version = 1;