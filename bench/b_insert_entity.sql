WITH l AS (
    INSERT INTO solution_b.entity_localizations (service_code, entity_code, field_code, entity_id)
    VALUES ('bench', 'bench', 'name', gen_random_uuid())
    RETURNING id
)
INSERT INTO solution_b.translations (resource_id, resource_type, language_id, value, version, status)
SELECT l.id, 'Entity', lg.id, 'bench value', 1, 'Draft'
FROM l CROSS JOIN solution_b.languages lg;