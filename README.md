# Тестовая БД PostgreSQL в Docker

## Что сделано
Поднята локальная тестовая база данных PostgreSQL 17 в Docker-контейнере через `docker compose`.
Данные хранятся в именованном volume `test_pg_data` (сохраняются между перезапусками).

## Окружение
| Параметр | Значение |
|---|---|
| Docker | 29.3.1 |
| Образ | `postgres:17-alpine` (PostgreSQL 17.11) |
| Контейнер | `test-postgres` |
| Порт на хосте | **5435** (5432, 5433, 5434 уже заняты другими контейнерами) |
| Volume | `test_pg_data` |

## Параметры подключения
| Параметр | Значение |
|---|---|
| Host | `localhost` |
| Port | `5435` |
| Database | `testdb` |
| User | `test_user` |
| Password | `test_password` |

Connection string:
```
postgresql://test_user:test_password@localhost:5435/testdb
```

## docker-compose.yml
```yaml
services:
  db:
    image: postgres:17-alpine
    container_name: test-postgres
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_password
    ports:
      - "5435:5432"
    volumes:
      - test_pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test_user -d testdb"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  test_pg_data:
```

## Выполненные команды

1. Проверка Docker и занятых портов:
```bash
docker --version
docker ps --format "{{.Names}} {{.Ports}}"
```

2. Запуск БД (в папке с `docker-compose.yml`):
```bash
docker compose up -d
```

3. Проверка статуса (ожидается `healthy`):
```bash
docker compose ps
```
Результат:
```
NAME            IMAGE                COMMAND                  SERVICE   STATUS                    PORTS
test-postgres   postgres:17-alpine   "docker-entrypoint.s…"   db        Up 10 seconds (healthy)   0.0.0.0:5435->5432/tcp
```

4. Проверка версии PostgreSQL:
```bash
docker exec test-postgres psql -U test_user -d testdb -c "SELECT version();"
```
Результат:
```
PostgreSQL 17.11 on x86_64-pc-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit
```

5. Проверка записи/чтения (тестовая таблица):
```bash
docker exec test-postgres psql -U test_user -d testdb -c "CREATE TABLE test_items (id SERIAL PRIMARY KEY, name TEXT NOT NULL); INSERT INTO test_items (name) VALUES ('hello'); SELECT * FROM test_items;"
```
Результат:
```
CREATE TABLE
INSERT 0 1
 id | name
----+-------
  1 | hello
```

6. Удаление тестовой таблицы и создание схем `solution_a`, `solution_b`, `solution_c`:
```bash
docker exec test-postgres psql -U test_user -d testdb -c "DROP TABLE test_items; CREATE SCHEMA solution_a; CREATE SCHEMA solution_b; CREATE SCHEMA solution_c;"
```

7. Проверка списка схем:
```bash
docker exec test-postgres psql -U test_user -d testdb -c "\dn"
```
Результат:
```
    Name    |       Owner
------------+-------------------
 public     | pg_database_owner
 solution_a | test_user
 solution_b | test_user
 solution_c | test_user
```

8. Создание таблицы `languages` в схемах `solution_a`, `solution_b`, `solution_c` и заполнение языками en, ru, tg, uz.

Структура (одинаковая во всех трёх схемах):

| Колонка | Тип | Ограничения |
|---|---|---|
| id | SERIAL | PRIMARY KEY |
| code_string | VARCHAR(10) | NOT NULL, UNIQUE |
| native_name | VARCHAR(100) | NOT NULL |
| is_default | BOOLEAN | NOT NULL, DEFAULT FALSE |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE |

Дополнительно: частичный уникальный индекс `languages_one_default_idx` по `is_default WHERE is_default` — язык по умолчанию может быть только один (по умолчанию выбран `en`).

Данные:

| code_string | native_name | is_default | is_active |
|---|---|---|---|
| en | English | true | true |
| ru | Русский | false | true |
| tg | Тоҷикӣ | false | true |
| uz | Oʻzbekcha | false | true |

Скрипт: [`sql/01_languages.sql`](sql/01_languages.sql) (выполняется в одной транзакции). Запуск:
```bash
docker cp sql/01_languages.sql test-postgres:/tmp/01_languages.sql
docker exec test-postgres psql -U test_user -d testdb -v ON_ERROR_STOP=1 -f /tmp/01_languages.sql
```

9. Проверка:
```bash
docker exec test-postgres psql -U test_user -d testdb -c "\dt solution_*.*"
docker exec test-postgres psql -U test_user -d testdb -c "SELECT * FROM solution_a.languages ORDER BY id;"
```
Результат (`\dt`):
```
   Schema   |   Name    | Type  |   Owner
------------+-----------+-------+-----------
 solution_a | languages | table | test_user
 solution_b | languages | table | test_user
 solution_c | languages | table | test_user
```
Результат (`solution_a.languages`, в b и c идентично):
```
 id | code_string | native_name | is_default | is_active
----+-------------+-------------+------------+-----------
  1 | en          | English     | t          | t
  2 | ru          | Русский     | f          | t
  3 | tg          | Тоҷикӣ      | f          | t
  4 | uz          | Oʻzbekcha   | f          | t
```

Проверка ограничения «один язык по умолчанию»: попытка вставить вторую строку с `is_default = TRUE` завершается ошибкой
`duplicate key value violates unique constraint "languages_one_default_idx"` (строка не добавлена).

10. Создание таблицы `payment_methods` в схемах `solution_a`, `solution_b`, `solution_c` (данные не добавлялись).

Структура (одинаковая во всех трёх схемах):

| Колонка | Тип | Ограничения |
|---|---|---|
| id | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` |
| code | VARCHAR(50) | NOT NULL, UNIQUE |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT `now()` |

Скрипт: [`sql/02_payment_methods.sql`](sql/02_payment_methods.sql). Запуск:
```bash
docker cp sql/02_payment_methods.sql test-postgres:/tmp/02_payment_methods.sql
docker exec test-postgres psql -U test_user -d testdb -v ON_ERROR_STOP=1 -f /tmp/02_payment_methods.sql
```

Проверка:
```bash
docker exec test-postgres psql -U test_user -d testdb -c "\dt solution_*.*"
```
Результат:
```
   Schema   |      Name       | Type  |   Owner
------------+-----------------+-------+-----------
 solution_a | languages       | table | test_user
 solution_a | payment_methods | table | test_user
 solution_b | languages       | table | test_user
 solution_b | payment_methods | table | test_user
 solution_c | languages       | table | test_user
 solution_c | payment_methods | table | test_user
```

11. Заполнение `payment_methods` тестовыми данными: по 100 000 строк в каждой из схем `solution_a`, `solution_b`, `solution_c` (всего 300 000). **Данные во всех трёх схемах полностью идентичны** (одинаковые `id`, `code`, `is_active`, `created_at`).

Как сделано (скрипт [`sql/03_seed_payment_methods.sql`](sql/03_seed_payment_methods.sql)): таблицы очищаются (`TRUNCATE`), набор генерируется один раз в `solution_a` через `generate_series`, затем копируется в `solution_b` и `solution_c` через `INSERT ... SELECT`. Правила генерации:
- `id` — UUID, генерируется автоматически
- `code` — `pm_000001` … `pm_100000`
- `is_active` — случайно, ~90% `true`
- `created_at` — случайная дата за последние 365 дней

Скрипт можно запускать повторно: он перезаливает данные (старые удаляются).

Запуск:
```bash
docker cp sql/03_seed_payment_methods.sql test-postgres:/tmp/03_seed_payment_methods.sql
docker exec test-postgres psql -U test_user -d testdb -v ON_ERROR_STOP=1 -f /tmp/03_seed_payment_methods.sql
```

Проверка количества:
```sql
SELECT count(*), count(*) FILTER (WHERE is_active), count(DISTINCT code) FROM solution_a.payment_methods;
```
Результат:
```
 s | count  | active | uniq_codes
---+--------+--------+------------
 a | 100000 |  89991 |     100000
 b | 100000 |  89991 |     100000
 c | 100000 |  89991 |     100000
```

Проверка идентичности (`EXCEPT` в обе стороны, пример для a и b; для c аналогично):
```sql
SELECT count(*) FROM (SELECT * FROM solution_a.payment_methods EXCEPT SELECT * FROM solution_b.payment_methods) x;
SELECT count(*) FROM (SELECT * FROM solution_b.payment_methods EXCEPT SELECT * FROM solution_a.payment_methods) x;
```
Результат: `0` во всех проверках (a−b, b−a, a−c, c−a) — различающихся строк нет.
Таблица `languages` во всех схемах тоже идентична (`EXCEPT` возвращает 0 строк).

12. Создание таблиц локализации (данные не добавлялись). Три варианта модели для сравнения:

| Схема | Подход | Таблицы |
|---|---|---|
| `solution_a` | нормализованная, коды `INT` | `entity_localizations`, `static_localizations`, `translations` |
| `solution_b` | то же, но коды `VARCHAR(100)` | `entity_localizations`, `static_localizations`, `translations` |
| `solution_c` | денормализованная, коды `INT`, коды лежат прямо в таблицах переводов | `entity_translations`, `static_translations` |

### solution_a и solution_b

`entity_localizations` — `UNIQUE (service_code, entity_code, field_code, entity_id)`

| Колонка | solution_a | solution_b |
|---|---|---|
| id | INT, IDENTITY, PK | INT, IDENTITY, PK |
| service_code | INT | VARCHAR(100) |
| entity_code | INT | VARCHAR(100) |
| field_code | INT | VARCHAR(100) |
| entity_id | UUID | UUID |

`static_localizations` — `UNIQUE (service_code, code)`

| Колонка | solution_a | solution_b |
|---|---|---|
| id | INT, IDENTITY, PK | INT, IDENTITY, PK |
| code | INT | VARCHAR(100) |
| service_code | INT | VARCHAR(100) |

`translations` (одинаковая в обеих схемах)

| Колонка | Тип | Ограничения |
|---|---|---|
| resource_id | INT | NOT NULL — id из `entity_localizations` или `static_localizations` |
| resource_type | VARCHAR(10) | NOT NULL, CHECK `Entity` / `Static` |
| language_id | INT | NOT NULL, FK → `<schema>.languages(id)` |
| value | TEXT | NOT NULL |
| version | INT | NOT NULL, DEFAULT 1 |
| status | VARCHAR(10) | NOT NULL, DEFAULT `Draft`, CHECK `Draft` / `Pending` / `Publish` / `Archive` / `Cancel` |

PK: `(resource_type, resource_id, language_id, version)`, индекс по `language_id`.

> `resource_id` полиморфный (указывает на одну из двух таблиц в зависимости от `resource_type`), поэтому внешний ключ на `entity_localizations` / `static_localizations` в PostgreSQL задать нельзя — целостность обеспечивает приложение.

### solution_c

`entity_translations` — `UNIQUE (service_code, entity_code, field_code, entity_id, language_id, version)`

| Колонка | Тип |
|---|---|
| id | INT, IDENTITY, PK |
| service_code, entity_code, field_code | INT, NOT NULL |
| entity_id | UUID, NOT NULL |
| language_id | INT, NOT NULL, FK → `solution_c.languages(id)` |
| value | TEXT, NOT NULL |
| version | INT, NOT NULL, DEFAULT 1 |
| status | VARCHAR(10), NOT NULL, DEFAULT `Draft`, тот же CHECK |

`static_translations` — `UNIQUE (service_code, code, language_id, version)`

| Колонка | Тип |
|---|---|
| id | INT, IDENTITY, PK |
| code, service_code | INT, NOT NULL |
| language_id | INT, NOT NULL, FK → `solution_c.languages(id)` |
| value | TEXT, NOT NULL |
| version | INT, NOT NULL, DEFAULT 1 |
| status | VARCHAR(10), NOT NULL, DEFAULT `Draft`, тот же CHECK |

В solution_c нет `resource_id` / `resource_type`, поэтому внешний ключ на `languages` работает обычным образом. Суррогатный `id` добавлен, потому что естественный ключ слишком широкий.

### Скрипты и запуск
- [`sql/04_localization_solution_a.sql`](sql/04_localization_solution_a.sql)
- [`sql/05_localization_solution_b.sql`](sql/05_localization_solution_b.sql)
- [`sql/06_localization_solution_c.sql`](sql/06_localization_solution_c.sql)

```bash
docker cp sql/04_localization_solution_a.sql test-postgres:/tmp/04_localization_solution_a.sql
docker exec test-postgres psql -U test_user -d testdb -v ON_ERROR_STOP=1 -f /tmp/04_localization_solution_a.sql
# аналогично для 05 и 06
```

### Проверка
```bash
docker exec test-postgres psql -U test_user -d testdb -c "\dt solution_*.*"
```
Результат:
```
   Schema   |         Name         | Type  |   Owner
------------+----------------------+-------+-----------
 solution_a | entity_localizations | table | test_user
 solution_a | languages            | table | test_user
 solution_a | payment_methods      | table | test_user
 solution_a | static_localizations | table | test_user
 solution_a | translations         | table | test_user
 solution_b | entity_localizations | table | test_user
 solution_b | languages            | table | test_user
 solution_b | payment_methods      | table | test_user
 solution_b | static_localizations | table | test_user
 solution_b | translations         | table | test_user
 solution_c | entity_translations  | table | test_user
 solution_c | languages            | table | test_user
 solution_c | payment_methods      | table | test_user
 solution_c | static_translations  | table | test_user
```

Проверка ограничений (в транзакциях с `ROLLBACK`, таблицы остались пустыми):

| Тест | Результат |
|---|---|
| Корректная вставка в `solution_a.translations` | OK |
| `status = 'Bad'` (solution_a, solution_c) | отклонено: нарушение CHECK `*_status_check` |
| `resource_type = 'Other'` (solution_b) | отклонено: нарушение CHECK `translations_resource_type_check` |
| `language_id = 999` (solution_a, solution_c) | отклонено: нарушение FK `*_language_id_fkey` |

13. Заполнение таблиц локализации тестовыми данными. Во всех трёх решениях **одинаковое содержимое, одинаковое количество строк и одинаковое распределение по статусам** — для честных бенчмарков.

### Что сгенерировано
- **Entity-ресурсы:** по 2 поля (`field_code` 1 = name, 2 = description) на каждый из 100 000 `payment_methods` → 200 000 записей (`service_code = 1` payment, `entity_code = 1` payment_method, `entity_id` = `payment_methods.id`).
- **Static-ресурсы:** 10 сервисов × 1 000 ключей → 10 000 записей.
- **Переводы:** каждый ресурс × 4 языка (en, ru, tg, uz). Значение `value` написано на языке перевода, например `Способ оплаты pm_000123 — название`.
- **Версии и статусы — без `random()`**, считаются от `id` ресурса, поэтому количества точные и повторяются при каждом перезапуске:
  - `id % 5 = 0` (20% ресурсов) → две версии: `version 1 = Archive`, `version 2 = Publish` (к значению добавляется ` (v2)`)
  - остальные ресурсы (80%) → одна версия, статус по `id % 20`: `1` → Draft, `2` → Pending, `3` → Cancel, прочие → Publish
  - статус и версии одинаковы для всех 4 языков одного ресурса

### Объём (одинаков в a, b и c)
| | Entity | Static | Всего |
|---|---|---|---|
| ресурсы (a, b: `*_localizations`) | 200 000 | 10 000 | 210 000 |
| переводы | 960 000 | 48 000 | **1 008 000** |
| Publish | 680 000 | 34 000 | 714 000 |
| Archive | 160 000 | 8 000 | 168 000 |
| Draft | 40 000 | 2 000 | 42 000 |
| Pending | 40 000 | 2 000 | 42 000 |
| Cancel | 40 000 | 2 000 | 42 000 |

Где лежат данные:
- `solution_a`, `solution_b`: ресурсы в `entity_localizations` / `static_localizations`, все 1 008 000 переводов в `translations`
- `solution_c`: 960 000 строк в `entity_translations` и 48 000 в `static_translations` (итого тоже 1 008 000)
- На каждый язык приходится ровно 1/4 переводов (252 000), `version 2` — 168 000 строк (по 42 000 на язык).

### Соответствие кодов INT ↔ VARCHAR (solution_a ↔ solution_b)
| Что | INT (a, c) | VARCHAR (b) |
|---|---|---|
| service_code | 1…10 | `payment`, `user`, `news`, `reference`, `notification`, `order`, `catalog`, `auth`, `report`, `billing` |
| entity_code | 1 | `payment_method` |
| field_code | 1 / 2 | `name` / `description` |
| static code | 1…1000 | `key_0001` … `key_1000` |

Те же `id` у `entity_localizations` и `static_localizations` в a и b (значения идентичны, отличаются только типы кодов).

### Как обеспечена идентичность
Скрипт [`sql/07_seed_localizations.sql`](sql/07_seed_localizations.sql) в одной транзакции:
1. очищает таблицы локализации (`TRUNCATE ... RESTART IDENTITY`) — скрипт можно перезапускать;
2. один раз детерминированно генерирует данные во временные staging-таблицы;
3. раскладывает их в a, b (с теми же `id` через `OVERRIDING SYSTEM VALUE`, в b коды переводятся в строки) и в c (коды встраиваются в строки переводов), вставка везде в одном порядке (`ORDER BY`);
4. сдвигает identity-последовательности на `max(id)`, чтобы вставка без `id` не падала;
5. выполняет `ANALYZE`.

Время выполнения на тестовой машине — около 1,5 минут (`\timing`).

Запуск:
```bash
docker cp sql/07_seed_localizations.sql test-postgres:/tmp/07_seed_localizations.sql
docker exec test-postgres psql -U test_user -d testdb -v ON_ERROR_STOP=1 -f /tmp/07_seed_localizations.sql
```

### Проверка
Скрипт [`sql/08_verify_localizations.sql`](sql/08_verify_localizations.sql):
```bash
docker cp sql/08_verify_localizations.sql test-postgres:/tmp/08_verify_localizations.sql
docker exec test-postgres psql -U test_user -d testdb -v ON_ERROR_STOP=1 -f /tmp/08_verify_localizations.sql
```

Результаты:

1. Количество строк:
```
 solution | entity_loc | static_loc | translations
----------+------------+------------+--------------
 a        |     200000 |      10000 |      1008000
 b        |     200000 |      10000 |      1008000
 c        |            |            |      1008000
```
2. Разбивка по статусам — совпадает в a, b, c (`equal = t` во всех 10 строках):
```
  kind  | status  |   a    |   b    |   c
--------+---------+--------+--------+--------
 Entity | Archive | 160000 | 160000 | 160000
 Entity | Cancel  |  40000 |  40000 |  40000
 Entity | Draft   |  40000 |  40000 |  40000
 Entity | Pending |  40000 |  40000 |  40000
 Entity | Publish | 680000 | 680000 | 680000
 Static | Archive |   8000 |   8000 |   8000
 Static | Cancel  |   2000 |   2000 |   2000
 Static | Draft   |   2000 |   2000 |   2000
 Static | Pending |   2000 |   2000 |   2000
 Static | Publish |  34000 |  34000 |  34000
```
3. Разбивка по `version` и `language_id` — совпадает в a, b, c (`equal = t` во всех 8 строках): `version 1` — по 210 000 на язык, `version 2` — по 42 000 на язык.
4. Идентичность содержимого (`EXCEPT` в обе стороны): a↔b (переводы, entity- и static-локализации с учётом соответствия кодов) и a↔c (entity- и static-переводы через JOIN с локализациями) → **0 различающихся строк** во всех 10 сравнениях.
5. Spot-check `pm_000123`: 12 переводов (2 поля; у поля `name` две версии Archive → Publish) в solution_a корректны на всех 4 языках.
6. Identity: вставка без `id` в `solution_a.entity_localizations` получает `id = 200001`, в `solution_b.static_localizations` — `id = 10001` (тест в транзакции с `ROLLBACK`).

14. Сравнение решений: размер на диске, скорость чтения, вставки, обновления и удаления.

### 14.1 Размер на диске
Скрипт [`sql/09_storage_size.sql`](sql/09_storage_size.sql), после `VACUUM ANALYZE`, только таблицы локализации (1 008 000 переводов в каждом решении):

| Решение | Данные | Индексы | Итого | Относительно a |
|---|---|---|---|---|
| solution_a (INT, 3 таблицы) | 113 MB | 62 MB | 175 MB | 100% |
| solution_b (VARCHAR, 3 таблицы) | 117 MB | 68 MB | 185 MB | +6% |
| solution_c (INT, 2 таблицы) | 121 MB | 100 MB | 222 MB | +27% |

- В `solution_c` больше всего занимает индекс `UNIQUE (service_code, entity_code, field_code, entity_id, language_id, version)` — 71 MB (в a и b аналогичный индекс меньше, потому что коды вынесены в `entity_localizations`, а в `translations` ключ короткий).
- В `solution_b` VARCHAR-коды увеличивают таблицу и индексы `entity_localizations` (15 MB / 22 MB против 12 MB / 16 MB в a); `translations` по размеру такая же (101 MB + 45 MB).

### 14.2 Методика замеров скорости
- **Инструменты:** `pgbench` (TPS и средняя задержка под нагрузкой) и `EXPLAIN (ANALYZE, BUFFERS)` (планы и время отдельных запросов).
- **Нагрузка:** 4 клиента, режим `-M prepared`, прогрев 5 с (отбрасывается) и замер 15 с на каждый сценарий и решение. Параметры (сущность, язык, сервис) случайные.
- **Одинаковые условия:** перед каждой серией данные пересоздаются скриптом `07_seed_localizations.sql`, затем `VACUUM ANALYZE`; запросы во всех решениях логически эквивалентны и возвращают одинаковое число строк (проверено).
- **Кэш:** `shared_buffers = 128 MB` (данные 175–222 MB, не помещаются целиком) и повтор при `shared_buffers = 1 GB` (помещаются). После замеров контейнер возвращён на 128 MB, данные пересозданы.
- **Окружение:** PostgreSQL 17.11 в Docker Desktop на Windows (28 CPU, 8 GB), диск — виртуальный, поэтому запись на диск (fsync) при коммите медленная.

Сценарии (скрипты в [`bench/`](bench/), файлы `a_*.sql`, `b_*.sql`, `c_*.sql`):

| Сценарий | Что делает | Результат |
|---|---|---|
| `read_entity` | все Publish-переводы полей name и description одной сущности на одном языке | 2 строки |
| `read_static` | все Publish-переводы статичных ключей одного сервиса на одном языке | 850 строк |
| `update_status` | смена статуса переводов поля name (version 1) у одной сущности на `Publish` | 4 строки |
| `delete_entity` | удаление сущности со всеми переводами; выполняется в транзакции с `ROLLBACK` (повторяемость, запись при коммите не входит) | a, b: 2 + 12 строк, c: 12 строк |
| `insert_entity` | новый ресурс с переводами на 4 языка | a, b: 1 + 4 строки, c: 4 строки |

В a и b запросы идут через JOIN `*_localizations` ↔ `translations`, в c — по одной таблице.

### 14.3 Результаты pgbench (TPS, больше — лучше)

Чтение и удаление (запись на диск при коммите не участвует):

| Сценарий | Кэш | solution_a | solution_b | solution_c |
|---|---|---|---|---|
| read_entity | 128 MB | 42 465 | 38 202 (−10%) | **48 353** (+14%) |
| read_entity | 1 GB | 43 388 | 40 667 (−6%) | **48 036** (+11%) |
| read_static | 128 MB | 2 375 | 2 304 (−3%) | **7 772** (3,3×) |
| read_static | 1 GB | 2 405 | 2 296 (−5%) | **7 789** (3,2×) |
| delete_entity | 128 MB | 19 778 | 15 933 (−19%) | **21 554** (+9%) |
| delete_entity | 1 GB | 19 072 | 16 680 (−13%) | **22 975** (+20%) |

Средняя задержка `read_entity`: 0,09–0,10 мс (a), 0,10–0,11 мс (b), 0,08 мс (c); `read_static`: 1,7 мс (a, b) и 0,5 мс (c).

Обновление и вставка — с записью на диск при коммите (`synchronous_commit = on`, по умолчанию). **Результаты нестабильны:** большая часть времени уходит на fsync, а не на сами запросы, поэтому порядок решений меняется от прогона к прогону:

| Сценарий | Кэш | solution_a | solution_b | solution_c |
|---|---|---|---|---|
| update_status | 128 MB | 629 | 722 | 673 |
| update_status | 1 GB | 1 891 | 722 | 858 |
| insert_entity | 128 MB | 847 | 672 | 1 916 |
| insert_entity | 1 GB | 1 520 | 1 914 | 1 635 |

Чтобы убрать влияние fsync и сравнить именно стоимость операций (индексы, число таблиц), те же сценарии повторены с `synchronous_commit = off` (кэш 1 GB, `delete_entity` для полноты):

| Сценарий | solution_a | solution_b | solution_c |
|---|---|---|---|
| update_status | 30 821 | 28 269 (−8%) | **36 678** (+19%) |
| insert_entity | 28 213 | **29 276** (+4%) | 28 634 (+1%) |
| delete_entity | 17 101 | 17 150 (0%) | **22 836** (+34%) |

> Погрешность: повторные прогоны одного и того же сценария различаются примерно на ±10% (например, delete_entity в a: 19 778 → 19 072 → 17 101). Различия меньше 10% считать значимыми нельзя. Вставка при `synchronous_commit = off` практически одинакова во всех решениях.

### 14.4 Планы запросов (`EXPLAIN ANALYZE`, кэш 128 MB)
Полный вывод: [`results/explain_128mb.txt`](results/explain_128mb.txt), запросы: [`sql/10_explain.sql`](sql/10_explain.sql). Во всех запросах всех решений используются индексы, `Seq Scan` нет (кроме чтения четырёх строк `languages`).

| Сценарий | solution_a | solution_b | solution_c |
|---|---|---|---|
| read_entity | 3 индексных сканирования (Nested Loop), 19 буферов, 0,068 мс | то же, 0,057 мс | 1 индексное сканирование, 11 буферов, 0,038 мс |
| read_static | Merge Join, читает 2 551 строку `translations` через PK ради 850 нужных, 242 буфера, 1,01 мс | то же, 246 буферов, 0,97 мс | Bitmap Heap Scan, 72 буфера, 0,218 мс |
| update_status | 0,216 мс | 0,199 мс | 0,123 мс |
| delete_entity | 0,135 мс | 0,123 мс | 0,056 мс |
| insert_entity | 0,366 мс | 0,312 мс | 0,245 мс |

Время выполнения самих запросов у всех решений измеряется долями миллисекунды; в `update_status` и `insert_entity` с обычным коммитом pgbench показывает 2–6 мс на транзакцию, то есть основное время уходит на запись на диск.

### 14.5 Выводы

Краткая сводка (TPS — при кэше 1 GB, обновление и вставка — без ожидания fsync; различия до ~10% — в пределах погрешности):

| Критерий | solution_a (INT, 3 табл.) | solution_b (VARCHAR, 3 табл.) | solution_c (INT, 2 табл.) | Лучше |
|---|---|---|---|---|
| Размер на диске | **175 MB** | 185 MB (+6%) | 222 MB (+27%) | a |
| Чтение сущности | 43 388 | 40 667 (−6%) | **48 036** (+11%) | c |
| Чтение страницы статики | 2 405 | 2 296 (−5%) | **7 789** (3,2×) | c |
| Удаление сущности | 19 072 | 16 680 (−13%) | **22 975** (+20%) | c |
| Обновление статуса | 30 821 | 28 269 (−8%) | **36 678** (+19%) | c |
| Вставка ресурса с переводами | 28 213 | 29 276 (+4%) | 28 634 (+1%) | ничья |
| Влияние кэша 128 MB → 1 GB | не заметно | не заметно | не заметно | — |
| Внешние ключи | нет FK на локализации (полиморфный `resource_id`) | то же | FK на `languages` есть, но коды дублируются в каждой строке | c (по целостности), a (по компактности) |
| Итог | компактно, скорость средняя | немного медленнее и больше a | быстрее всех, но на 27% больше | зависит от приоритета: место → a, скорость чтения → c |

Подробности:
- **Размер:** `solution_a` самое компактное; `solution_b` на 6% больше из-за строковых кодов; `solution_c` на 27% больше из-за широкого уникального индекса и повторения кодов в каждой строке перевода.
- **Чтение статики по сервису:** `solution_c` в 3 раза быстрее — нет JOIN, читается только нужное. В a и b чтение идёт по PK `translations` по всем статусам и языкам ресурса, из 2 551 строк нужно 850.
- **Чтение сущности и удаление:** `solution_c` быстрее на 10–35% (одна таблица вместо JOIN).
- **Вставка и обновление:** при обычном коммите разница тонет в стоимости fsync; без него вставка одинакова, обновление в c быстрее на ~19%.
- **VARCHAR-коды (b) против INT (a):** `solution_b` немного медленнее и больше (в пределах 5–20% в чтении и удалении), на вставку и обновление практически не влияет.
- **Кэш 128 MB против 1 GB:** на чтение и удаление не повлиял заметно (в пределах погрешности): рабочий набор случайных запросов оказывается в кэше PostgreSQL и в кэше ОС Docker. Эффект кэша мог бы проявиться на холодном старте или при большем объёме данных.
- **Ограничение моделей a и b:** полиморфный `resource_id` не позволяет задать внешний ключ на локализации (см. шаг 12); `solution_c` этого лишена, но дублирует коды в каждой строке.

### 14.6 Файлы и повторение замеров
- [`bench/run_bench.ps1`](bench/run_bench.ps1) — раннер (пересоздаёт данные, прогревает, замеряет, сохраняет CSV и лог)
- [`bench/`](bench/) — 15 pgbench-скриптов (`{a,b,c}_{read_entity,read_static,update_status,delete_entity,insert_entity}.sql`)
- [`results/`](results/) — `bench_128mb.csv|log`, `bench_1gb.csv|log`, `bench_1gb_syncoff.csv|log`, `explain_128mb.txt`

```powershell
# все сценарии, текущий кэш
.\bench\run_bench.ps1 -Tag my_run
# только запись, без ожидания fsync
.\bench\run_bench.ps1 -Tag my_run_syncoff -SyncCommitOff -Scenarios update_status,insert_entity
```
Смена кэша: `ALTER SYSTEM SET shared_buffers = '1GB';` и `docker restart test-postgres`; возврат: `ALTER SYSTEM RESET shared_buffers;` и перезапуск.
Раннер каждый раз пересоздаёт данные в таблицах локализации, поэтому после замеров состояние БД остаётся эталонным.

## Полезные команды
```bash
# Подключиться к psql внутри контейнера
docker exec -it test-postgres psql -U test_user -d testdb

# Логи
docker compose logs -f db

# Остановить (данные сохраняются)
docker compose down

# Остановить и удалить данные (volume)
docker compose down -v
```
