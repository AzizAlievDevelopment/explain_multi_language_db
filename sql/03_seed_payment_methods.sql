BEGIN;

TRUNCATE solution_a.payment_methods, solution_b.payment_methods, solution_c.payment_methods;

-- Набор данных генерируется один раз в solution_a
INSERT INTO solution_a.payment_methods (code, is_active, created_at)
SELECT 'pm_' || lpad(i::text, 6, '0'),
       random() < 0.9,
       now() - (random() * interval '365 days')
FROM generate_series(1, 100000) AS i;

-- В solution_b и solution_c копируется тот же набор (одинаковые id, code, is_active, created_at)
INSERT INTO solution_b.payment_methods (id, code, is_active, created_at)
SELECT id, code, is_active, created_at FROM solution_a.payment_methods;

INSERT INTO solution_c.payment_methods (id, code, is_active, created_at)
SELECT id, code, is_active, created_at FROM solution_a.payment_methods;

COMMIT;

ANALYZE solution_a.payment_methods;
ANALYZE solution_b.payment_methods;
ANALYZE solution_c.payment_methods;
