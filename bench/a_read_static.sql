\set s random(1, 10)
\set lang random(1, 4)
SELECT l.code, t.value
FROM solution_a.static_localizations l
JOIN solution_a.translations t ON t.resource_type = 'Static' AND t.resource_id = l.id
WHERE l.service_code = :s
  AND t.language_id = :lang AND t.status = 'Publish';