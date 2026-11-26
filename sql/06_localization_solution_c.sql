BEGIN;

CREATE TABLE solution_c.entity_translations (
    id            INT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_code  INT         NOT NULL,
    entity_code   INT         NOT NULL,
    field_code    INT         NOT NULL,
    entity_id     UUID        NOT NULL,
    language_id   INT         NOT NULL REFERENCES solution_c.languages (id),
    value         TEXT        NOT NULL,
    version       INT         NOT NULL DEFAULT 1,
    status        VARCHAR(10) NOT NULL DEFAULT 'Draft'
                  CHECK (status IN ('Draft', 'Pending', 'Publish', 'Archive', 'Cancel')),
    UNIQUE (service_code, entity_code, field_code, entity_id, language_id, version)
);
CREATE INDEX entity_translations_language_id_idx ON solution_c.entity_translations (language_id);

CREATE TABLE solution_c.static_translations (
    id            INT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          INT         NOT NULL,
    service_code  INT         NOT NULL,
    language_id   INT         NOT NULL REFERENCES solution_c.languages (id),
    value         TEXT        NOT NULL,
    version       INT         NOT NULL DEFAULT 1,
    status        VARCHAR(10) NOT NULL DEFAULT 'Draft'
                  CHECK (status IN ('Draft', 'Pending', 'Publish', 'Archive', 'Cancel')),
    UNIQUE (service_code, code, language_id, version)
);
CREATE INDEX static_translations_language_id_idx ON solution_c.static_translations (language_id);

COMMIT;
