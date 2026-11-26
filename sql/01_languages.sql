BEGIN;

-- solution_a
CREATE TABLE solution_a.languages (
    id           SERIAL PRIMARY KEY,
    code_string  VARCHAR(10)  NOT NULL UNIQUE,
    native_name  VARCHAR(100) NOT NULL,
    is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);
CREATE UNIQUE INDEX languages_one_default_idx ON solution_a.languages (is_default) WHERE is_default;
INSERT INTO solution_a.languages (code_string, native_name, is_default, is_active) VALUES
    ('en', 'English',   TRUE,  TRUE),
    ('ru', 'Русский',   FALSE, TRUE),
    ('tg', 'Тоҷикӣ',    FALSE, TRUE),
    ('uz', 'Oʻzbekcha', FALSE, TRUE);

-- solution_b
CREATE TABLE solution_b.languages (
    id           SERIAL PRIMARY KEY,
    code_string  VARCHAR(10)  NOT NULL UNIQUE,
    native_name  VARCHAR(100) NOT NULL,
    is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);
CREATE UNIQUE INDEX languages_one_default_idx ON solution_b.languages (is_default) WHERE is_default;
INSERT INTO solution_b.languages (code_string, native_name, is_default, is_active) VALUES
    ('en', 'English',   TRUE,  TRUE),
    ('ru', 'Русский',   FALSE, TRUE),
    ('tg', 'Тоҷикӣ',    FALSE, TRUE),
    ('uz', 'Oʻzbekcha', FALSE, TRUE);

-- solution_c
CREATE TABLE solution_c.languages (
    id           SERIAL PRIMARY KEY,
    code_string  VARCHAR(10)  NOT NULL UNIQUE,
    native_name  VARCHAR(100) NOT NULL,
    is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);
CREATE UNIQUE INDEX languages_one_default_idx ON solution_c.languages (is_default) WHERE is_default;
INSERT INTO solution_c.languages (code_string, native_name, is_default, is_active) VALUES
    ('en', 'English',   TRUE,  TRUE),
    ('ru', 'Русский',   FALSE, TRUE),
    ('tg', 'Тоҷикӣ',    FALSE, TRUE),
    ('uz', 'Oʻzbekcha', FALSE, TRUE);

COMMIT;
