# Отчёт по Лабораторной работе №2: Написание запросов

* **Схема БД**: lab01
* **СУБД**: PostgreSQL 16

## Запросы на чтение данных (SELECT)

### 1. Простая выборка (WHERE, ORDER BY, LIMIT)
**Назначение:** Получить список 5 самых новых активных клиентов, родившихся после 1990 года. Используется для формирования списка новых, молодых клиентов для целевого маркетинга или обзвона
```sql
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
```

### 2. Агрегирующий запрос (GROUP BY, SUM, AVG)
**Назначение:** Подсчитать общее количество счетов и средний баланс для каждой валюты. Мониторинга ликвидности и распределения активов по валютам в целом по банку

```sql
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
```
### 3. Агрегирующий запрос с фильтрацией групп (HAVING и JOIN)
**Назначение:** Найти филиалы, в которых работает более одного сотрудника. Этот запрос помогает выявить ключевые, крупные офисы

```sql
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
```

### 4. Запрос с некоррелированным подзапросом (IN)
**Назначение:** Получить список клиентов, имеющих действующий счет с балансом больше 1000 USD. Используется для выявления VIP-клиентов

```sql
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
```

### 5. Запрос с CTE (Common Table Expression) и JOIN
**Назначение:** Найти клиентов с высоким уровнем риска (например, risk_level >= 4) и вывести их полный адрес Используется для усиленного мониторинга AML/KYC

```sql
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
```

## Модифицирующие запросы (INSERT / UPDATE / DELETE)

### 1. INSERT
**Контекст использования:** Заполнить таблицы начальными данными для тестирования и демонстрации работы БД<br>
**Ограничения:**
- Некоторые столбцы должны иметь уникальные значения (например в таблице product: code должен быть уникальным (unique))
- Некоторые столбцы не могут быть null (например в таблице exchange_rate: все столбцы должны быть не null (not null))
- Некоторые столбцы не могут быть созданны, если не существует колонки, с которой они связаны (Например в employee branch_id без id в branch (`alter table employee
    add foreign key (branch_id) references branch(id) on delete restrict;`))

```sql
INSERT INTO lab01.currency (code, name) VALUES
('USD', 'US Dollar'),
('EUR', 'Euro'),
('RUB', 'Russian Ruble'),
('KZT', 'Kazakhstani Tenge'),
('GBP', 'British Pound');

INSERT INTO lab01.address (id, country, city, street, house, postal_code) VALUES
(101, 'Россия', 'Москва', 'Тверская ул.', '12', '125009'),
(102, 'Россия', 'Санкт-Петербург', 'Невский пр.', '50', '191000'),
(103, 'Казахстан', 'Алматы', 'пр. Абая', '150', '050060'),
(104, 'США', 'Нью-Йорк', 'Wall Street', '11', '10005'),
(105, 'Россия', 'Москва', 'ул. Ленина', '5', '115000');

INSERT INTO lab01.branch (id, code, name, address_id, opened_at) VALUES
(201, 'MSK01', 'Центральный Московский', 101, '2010-05-01'),
(202, 'SPB01', 'Северный филиал', 102, '2015-10-10'),
(203, 'ALM01', 'Филиал Алматы', 103, '2018-01-20');

INSERT INTO lab01.employee (id, branch_id, full_name, position, work_email, hired_at) VALUES
(301, 201, 'Петров Алексей Сергеевич', 'Менеджер', 'a.petrov@bank.ru', '2020-03-15'),
(302, 201, 'Смирнова Елена Игоревна', 'Кассир', 'e.smirnova@bank.ru', '2021-08-01'),
(303, 202, 'Васильев Олег Петрович', 'Начальник отдела', 'o.vasilyev@bank.ru', '2019-01-25'),
(304, 203, 'Королева Алия Канат', 'Консультант', 'a.koroleva@bank.ru', '2022-06-10'),
(305, 201, 'Сидоров Михаил Иванович', 'Менеджер', 'm.sidorov@bank.ru', '2023-01-01');

INSERT INTO lab01.customer (id, full_name, birth_date, phone, email, status) VALUES
(401, 'Зайцев Артем Владимирович', '1985-04-12', '79111111111', 'zaitsev.a@test.ru', 'active'),
(402, 'Комарова Анна Сергеевна', '1995-07-25', '79222222222', 'komarova.a@test.ru', 'active'),
(403, 'Волков Борис Игоревич', '1970-11-01', '79333333333', 'volkov.b@test.ru', 'active'),
(404, 'Лебедева Кристина Олеговна', '2000-01-05', '79444444444', 'lebedeva.k@test.ru', 'inactive'),
(405, 'Орлов Дмитрий Николаевич', '1998-03-18', '79555555555', 'orlov.d@test.ru', 'active');

INSERT INTO lab01.customer_profile (customer_id, risk_level, kyc_status, occupation, income_bracket, pep_flag) VALUES
(401, 2, 'verified', 'Engineer', 'High', FALSE),
(402, 1, 'verified', 'Student', 'Low', FALSE),
(403, 5, 'pending', 'Business Owner', 'Very High', TRUE),
(404, 3, 'expired', 'Retired', 'Medium', FALSE),
(405, 1, 'verified', 'Data Analyst', 'High', FALSE);

INSERT INTO lab01.customer_address (customer_id, address_id, type, is_primary) VALUES
(401, 101, 'residential', TRUE),
(402, 101, 'residential', TRUE),
(403, 104, 'residential', TRUE),
(404, 102, 'residential', TRUE),
(405, 105, 'residential', TRUE);

INSERT INTO lab01.product (id, code, name, category, terms_json) VALUES
(501, 'DEP_STD', 'Сберегательный счет "Стандарт"', 'Deposit', '{"rate": 0.05}'),
(502, 'LOAN_MORT', 'Ипотечный кредит', 'Loan', '{"rate": 0.12, "max_term": 360}'),
(503, 'CHK_PREM', 'Текущий счет "Премиум"', 'Checking', '{"fee": 10.00}');

INSERT INTO lab01.account (id, account_number, customer_id, product_id, currency_code, status, balance) VALUES
(601, '40817810000010000001', 401, 503, 'USD', 'active', 1500.00),
(602, '40817810000010000002', 401, 501, 'RUB', 'active', 500000.00),
(603, '40817810000010000003', 402, 503, 'EUR', 'active', 50.50),
(604, '40817810000010000004', 403, 503, 'USD', 'active', 100000.00),
(605, '40817810000010000005', 404, 501, 'RUB', 'closed', 0.00);

INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description) VALUES
(701, 601, 'deposit', 500.00, 'USD', 'Initial deposit'),
(702, 601, 'withdrawal', 50.00, 'USD', 'ATM withdrawal'),
(703, 602, 'deposit', 100000.00, 'RUB', 'Monthly salary'),
(704, 604, 'deposit', 100000.00, 'USD', 'Large business deposit'),
(705, 603, 'withdrawal', 10.00, 'EUR', 'Online payment');

INSERT INTO lab01.loan (id, customer_id, product_id, principal_amount, currency_code, annual_rate_pct, maturity_date, linked_account_id) VALUES
(801, 401, 502, 1000000.00, 'RUB', 10.50, '2035-12-31', 602),
(802, 405, 502, 50000.00, 'USD', 8.00, '2028-06-01', 601);

INSERT INTO lab01.exchange_rate (id, base_code, quote_code, rate) VALUES
(901, 'USD', 'RUB', 90.50),
(902, 'USD', 'EUR', 0.92),
(903, 'EUR', 'RUB', 98.37);

INSERT INTO lab01.card (id, account_id, pan, embossed_name, exp_month, exp_year, status) VALUES
(1001, 601, '4000111122223333', 'ARTEM ZAITSEV', 12, 27, 'active'),
(1002, 603, '5000444455556666', 'ANNA KOMAROVA', 10, 25, 'active');
```

### 2. UPDATE: Одиночное
**Контекст использования:** Зополнение счета клиента на сумму 1000.00 USD<br>
**Ограничения и условия:**
- Счет должен быть активным
- Баланс должен быть скорректирован только для указанного номера счета

```sql
UPDATE
    account
SET
    balance = balance + 1000.00
WHERE
    account_number = '40817810000010000001'
AND
    status = 'active';
```

### 3. UPDATE: Массовое изменение
**Контекст использования:** Клиенты с уровнем риска 3 и выше требуют пересмотра их KYC статуса<br>
**Ограничения и условия:**
- Обновление должно происходить только для клиентов с текущим статусом 'verified'
- Ограничение уровень риска должно быть 3 и выше

```sql
UPDATE
    customer_profile
SET
    kyc_status = 'pending_review', updated_at = NOW()
WHERE
    risk_level >= 3
AND
    kyc_status = 'verified';
```

### 4. DELETE
**Контекст использования:** Адрес в США (id = 104) больше не используется и не связан с активными клиентами<br>
**Ограничения и условия:**
- Адрес должен быть удален только если он не связан с активными клиентами
- Удаление должно быть безопасным и не нарушать целостность данных (либо внешние ключи должны быть настроены на автоматическое удаление)

```sql
UPDATE
    customer_profile
SET
    kyc_status = 'pending_review', updated_at = NOW()
WHERE
    risk_level >= 3
AND
    kyc_status = 'verified';
```

## Представления (VIEW)

### 1. Обычное Представление (Standard VIEW)
**Контекст использования:** Предоставить оперативный сводный список всех активных кредитов клиента, включая основную сумму, ставку и связанный счет для погашения<br>
**Причина выбора:** Данные о кредитах являются оперативными и могут часто меняться (например, при ежемесячном погашении или смене статуса). Обычное представление не хранит данные на диске, а выполняет базовый запрос каждый раз при обращении.
Это гарантирует, что система всегда видят самые актуальные данные о текущем портфеле кредитов в реальном времени

```sql
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
```

### 2. Материализованное Представление (MATERIALIZED VIEW)
**Контекст использования:** Ежедневный расчет суммарного баланса (в USD) для высокорисковых клиентов (risk_level >= 3) для быстрого мониторинга общего объема рисковых активов<br>
**Причина выбора:**
- Сложность/Ресурсоемкость: Запрос включает JOIN трех таблиц, фильтрацию, агрегацию (SUM) и подзапросы для расчета конвертации валют (который является ресурсоемким).
- Низкая частота обновления: Данный отчет используется для ежедневного (или ежечасного) мониторинга рисков, а не для транзакций в реальном времени.

```sql
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
```

## Ответы на вопросы
### 1. Какие потенциальные риски могут возникнуть при некорректном использовании DELETE или UPDATE без WHERE?
Основной риск — катастрофическая потеря или порча данных
- Приводит к удалению всех записей в таблице, вызывая полную потерю данных и потенциальный сбой системы
- риводит к обновлению всех записей одинаковым значением (например, обнуление всех балансов), что нарушает целостность данных
- Масштабные операции без фильтрации вызывают длительные блокировки таблицы, что может привести к простою всей системы

### 2. Почему важно не использовать * в запросах
Использование SELECT * является плохой практикой:
- Производительность: Извлекаются все столбцы, включая ненужные, что увеличивает нагрузку на сеть и память сервера
- Неустойчивость кода: При изменении структуры таблицы (добавлении/удалении столбца) код приложения, использующий *, может сломаться, так как порядок и количество столбцов изменится

### 3. Какие проблемы могут быть при параллельном выполнении запросов?
Параллельное выполнение запросов (конкурентность) без адекватной изоляции транзакций может привести к нарушению консистентности данных
- Потерянное обновление: Две транзакции читают одно и то же значение, а затем обе записывают, при этом изменение одной из транзакций теряется.
- Транзакция читает данные, измененные другой транзакцией, которая еще не зафиксирована. Если вторая транзакция отменяется, первая оперировала неверными данными.
- Неповторяющееся чтение: Транзакция читает строку дважды, и между чтениями другая транзакция изменяет или удаляет эту строку.