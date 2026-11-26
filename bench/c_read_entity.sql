\set k random(1, 100000)
\set lang random(1, 4)
SELECT field_code, value
FROM solution_c.entity_translations
WHERE service_code = 1 AND entity_code = 1 AND field_code IN (1, 2)
  AND entity_id = (SELECT id FROM solution_c.payment_methods WHERE code = 'pm_' || lpad(CAST(:k AS text), 6, '0'))
  AND language_id = :lang AND status = 'Publish'
ORDER BY field_code;