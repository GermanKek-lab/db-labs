SET search_path TO lab01, public;

/*
Получить список 5 самых новых активных клиентов, родившихся после 1990 года.
Используется для формирования списка новых, молодых клиентов для целевого маркетинга или обзвона
*/
SELECT
    id,
    full_name,
    email,
    created_at
FROM
    lab01.customer
WHERE
    status = 'active'
    AND birth_date >= '1990-01-01'
ORDER BY
    created_at DESC
LIMIT 5;

/*
Подсчитать общее количество счетов и средний баланс для каждой валюты.
Мониторинга ликвидности и распределения активов по валютам в целом по банку
*/
SELECT
    currency_code,
    COUNT(id) AS total_accounts,
    SUM(balance) AS total_balance,
    AVG(balance) AS average_balance
FROM
    account
GROUP BY
    currency_code
ORDER BY
    total_balance DESC;

/*
Найти филиалы, в которых работает более одного сотрудника.
Этот запрос помогает выявить ключевые, крупные офисы
*/
SELECT
    b.name AS branch_name,
    COUNT(e.id) AS employee_count
FROM
    branch b
JOIN
    employee e ON b.id = e.branch_id
WHERE
    b.is_active = TRUE
GROUP BY
    b.name
HAVING
    COUNT(e.id) > 1
ORDER BY
    employee_count DESC;

/*
Получить список клиентов, имеющих действующий счет с балансом больше 1000 USD.
Используется для выявления VIP-клиентов
*/
SELECT
    id,
    full_name,
    phone
FROM
    customer
WHERE
    id IN (
        SELECT
            customer_id
        FROM
            account
        WHERE
            status = 'active' AND balance > 1000 AND currency_code = 'USD'
    )
ORDER BY
    full_name;

/*
Найти клиентов с высоким уровнем риска (например, risk_level >= 4) и вывести их полный адрес.
Используется для усиленного мониторинга AML/KYC
*/
WITH HighRiskCustomers AS (
    SELECT
        customer_id
    FROM
        customer_profile
    WHERE
        risk_level >= 4
)
SELECT
    c.full_name,
    cp.risk_level,
    a.country,
    a.city,
    a.street || ', ' || a.house AS full_address
FROM
    customer c
JOIN
    HighRiskCustomers hrc ON c.id = hrc.customer_id
JOIN
    customer_profile cp ON c.id = cp.customer_id
JOIN
    customer_address ca ON c.id = ca.customer_id AND ca.is_primary = TRUE
JOIN
    address a ON ca.address_id = a.id
ORDER BY
    c.full_name;