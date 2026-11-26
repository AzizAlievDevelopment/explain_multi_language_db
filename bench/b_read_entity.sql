\set k random(1, 100000)
\set lang random(1, 4)
SELECT l.field_code, t.value
FROM solution_b.entity_localizations l
JOIN solution_b.translations t ON t.resource_type = 'Entity' AND t.resource_id = l.id
WHERE l.service_code = 'payment' AND l.entity_code = 'payment_method' AND l.field_code IN ('name', 'description')
  AND l.entity_id = (SELECT id FROM solution_b.payment_methods WHERE code = 'pm_' || lpad(CAST(:k AS text), 6, '0'))
  AND t.language_id = :lang AND t.status = 'Publish'
ORDER BY l.field_code;