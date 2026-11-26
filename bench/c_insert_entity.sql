WITH u AS (SELECT gen_random_uuid() AS id)
INSERT INTO solution_c.entity_translations (service_code, entity_code, field_code, entity_id, language_id, value, version, status)
SELECT 99, 1, 1, u.id, lg.id, 'bench value', 1, 'Draft'
FROM u CROSS JOIN solution_c.languages lg;