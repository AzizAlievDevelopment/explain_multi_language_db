\set s random(1, 10)
\set lang random(1, 4)
SELECT code, value
FROM solution_c.static_translations
WHERE service_code = :s
  AND language_id = :lang AND status = 'Publish';