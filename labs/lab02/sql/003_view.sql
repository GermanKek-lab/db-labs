SET search_path TO lab01, public;

/*
Предоставить оперативный сводный список всех активных кредитов клиента,
включая основную сумму, ставку и связанный счет для погашения

Тип: Обычное Представление (Standard View)

Причина выбора: Данные о кредитах являются оперативными и могут часто меняться (например, при ежемесячном погашении или смене статуса).
Обычное представление не хранит данные на диске, а выполняет базовый запрос каждый раз при обращении.
Это гарантирует, что система всегда видят самые актуальные данные о текущем портфеле кредитов в реальном времени
*/
CREATE OR REPLACE VIEW active_customer_loans AS
SELECT
    l.id AS loan_id,
    c.full_name AS customer_name,
    l.principal_amount,
    l.annual_rate_pct,
    l.maturity_date,
    a.account_number AS linked_account
FROM
    loan l
JOIN
    customer c ON l.customer_id = c.id
LEFT JOIN
    account a ON l.linked_account_id = a.id
WHERE
    l.status = 'active';

/*
Ежедневный расчет суммарного баланса (в USD) для высокорисковых клиентов (risk_level >= 3) для быстрого мониторинга общего объема рисковых активов

Тип: Материализованное Представление (Materialized View)

Причина выбора:
    - Сложность/Ресурсоемкость: Запрос включает JOIN трех таблиц, фильтрацию, агрегацию (SUM) и подзапросы для расчета конвертации валют (который является ресурсоемким).
    - Низкая частота обновления: Данный отчет используется для ежедневного (или ежечасного) мониторинга рисков, а не для транзакций в реальном времени.

Преимущество: Хранение результата запроса на диске обеспечивает мгновенный доступ к отчету, снижая нагрузку на базу данных.
Отчет нужно лишь периодически обновлять (REFRESH MATERIALIZED VIEW), а не пересчитывать при каждом открытии.
*/
CREATE MATERIALIZED VIEW daily_customer_risk_summary AS
WITH RiskBalances AS (
    SELECT
        a.customer_id,
        a.balance,
        a.currency_code
    FROM
        account a
    JOIN
        customer_profile cp ON a.customer_id = cp.customer_id
    WHERE
        cp.risk_level >= 3 AND a.status = 'active'
),
ConversionRates AS (
    SELECT rate FROM exchange_rate WHERE base_code = 'USD' AND quote_code = 'RUB'
)
SELECT
    rb.customer_id,
    c.full_name,
    cp.risk_level,
    SUM(
        CASE rb.currency_code
            WHEN 'USD' THEN rb.balance
            WHEN 'RUB' THEN rb.balance / (SELECT rate FROM exchange_rate WHERE base_code = 'USD' AND quote_code = 'RUB')
            WHEN 'EUR' THEN rb.balance / (SELECT rate FROM exchange_rate WHERE base_code = 'USD' AND quote_code = 'EUR')
            ELSE 0
        END
    ) AS total_balance_usd_equiv
FROM
    RiskBalances rb
JOIN
    customer c ON rb.customer_id = c.id
JOIN
    customer_profile cp ON rb.customer_id = cp.customer_id
GROUP BY
    rb.customer_id, c.full_name, cp.risk_level
WITH DATA;