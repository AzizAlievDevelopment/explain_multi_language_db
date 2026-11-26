\set k random(1, 100000)
\set lang random(1, 4)
SELECT l.field_code, t.value
FROM solution_a.entity_localizations l
JOIN solution_a.translations t ON t.resource_type = 'Entity' AND t.resource_id = l.id
WHERE l.service_code = 1 AND l.entity_code = 1 AND l.field_code IN (1, 2)
  AND l.entity_id = (SELECT id FROM solution_a.payment_methods WHERE code = 'pm_' || lpad(CAST(:k AS text), 6, '0'))
  AND t.language_id = :lang AND t.status = 'Publish'
ORDER BY l.field_code;