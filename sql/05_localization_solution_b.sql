BEGIN;

CREATE TABLE solution_b.entity_localizations (
    id            INT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_code  VARCHAR(100) NOT NULL,
    entity_code   VARCHAR(100) NOT NULL,
    field_code    VARCHAR(100) NOT NULL,
    entity_id     UUID         NOT NULL,
    UNIQUE (service_code, entity_code, field_code, entity_id)
);

CREATE TABLE solution_b.static_localizations (
    id            INT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          VARCHAR(100) NOT NULL,
    service_code  VARCHAR(100) NOT NULL,
    UNIQUE (service_code, code)
);

-- resource_id полиморфный (entity_localizations.id или static_localizations.id),
-- поэтому FK на эти таблицы невозможен; целостность обеспечивает приложение.
CREATE TABLE solution_b.translations (
    resource_id    INT          NOT NULL,
    resource_type  VARCHAR(10)  NOT NULL CHECK (resource_type IN ('Entity', 'Static')),
    language_id    INT          NOT NULL REFERENCES solution_b.languages (id),
    value          TEXT         NOT NULL,
    version        INT          NOT NULL DEFAULT 1,
    status         VARCHAR(10)  NOT NULL DEFAULT 'Draft'
                   CHECK (status IN ('Draft', 'Pending', 'Publish', 'Archive', 'Cancel')),
    PRIMARY KEY (resource_type, resource_id, language_id, version)
);
CREATE INDEX translations_language_id_idx ON solution_b.translations (language_id);

COMMIT;
