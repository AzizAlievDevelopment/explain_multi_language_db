\set s random(1, 10)
\set lang random(1, 4)
SELECT l.code, t.value
FROM solution_b.static_localizations l
JOIN solution_b.translations t ON t.resource_type = 'Static' AND t.resource_id = l.id
WHERE l.service_code = (ARRAY['payment','user','news','reference','notification','order','catalog','auth','report','billing'])[:s]
  AND t.language_id = :lang AND t.status = 'Publish';