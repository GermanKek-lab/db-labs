# Отчёт по Лабораторной работе №3: Индексы

* **Схема БД**: lab01
* **СУБД**: PostgreSQL 16

## 1. Анализ запросов
### Запрос 1
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
**Используемые столбцы:**
- **WHERE:** status, birth_date
- **ORDER BY:** created_at
- **SELECT:** id, full_name, email, created_at

**Типичное использование:**
- **status** — классический кандидат для поиска
- **birth_date** — используется для фильтрации по возрасту
- **created_at** — частый кандидат для сортировки

**Предлагаемый индекс:**
- **Тип**: составной B-tree
- **Столбцы**: (status, birth_date, created_at DESC)
- Комментарий:
  - status (равенство) идёт первым — сужает набор строк
  - birth_date (условие >=) — вторым
  - created_at DESC — позволяет отдать строки сразу в нужном порядке без дополнительной сортировки, особенно эффективно с LIMIT 5

### Запрос 2
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

**Используемые столбцы:**
- GROUP BY: currency_code
- SELECT: currency_code, агрегаты по balance
- ORDER BY: total_balance (вычисляемое агрегатное поле)

**Типичное использование:**
- currency_code — частый разрез для отчетов по счетам (ликвидность по валютам)
- balance — важный финансовый показатель, но в этом запросе по нему нет фильтра, только агрегирование

**Предлагаемый индекс:**
- Тип: простой B-tree
- Столбцы: (currency_code)
- Комментарий:
  - Индекс упорядочивает строки по currency_code, что удешевляет группировку (GROUP BY)
  - Может использоваться в других запросах с фильтрацией по валюте и тем самым повышает общую полезность индекса

### Запрос 3
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
**Используемые столбцы:**
- JOIN: b.id, e.branch_id
- WHERE: b.is_active
- GROUP BY: b.name 
- SELECT: b.name, COUNT(e.id)

**Типичное использование:**
- employee.branch_id — типичный столбец для связки сотрудников с филиалом и отчетов по филиалам
- branch.is_active — часто используется в фильтрах (работаем только с активными филиалами)
- branch.name — используется для отображения и группировки, но реже как критерий поиска

**Предлагаемый индекс:**
- Индекс 1
  - Тип: простой B-tree
  - Столбцы: employee(branch_id)
  - Комментарий: ускоряет JOIN b.id = e.branch_id и любые выборки сотрудников по филиалу
- Инекс 2
  - Тип: простой B-tree
  - Столбцы: branch(is_active)
  - Комментарий: делает фильтрацию по b.is_active = TRUE более дешёвой, особенно если активных филиалов существенно меньше, чем всех


### Запрос 4
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
            status = 'active'
            AND balance > 1000
            AND currency_code = 'USD'
    )
ORDER BY
    full_name;
```
**Используемые столбцы:**
- Внутренний подзапрос (account):
  - WHERE: status, balance, currency_code
  - SELECT: customer_id
- Вншний запрос (customer):
  - WHERE: id (через IN ( ... customer_id ...))
  - ORDER BY: full_name
  - SELECT: id, full_name, phone

**Типичное использование:**
- account.status — частый критерий фильтрации (active/closed)
- account.currency_code — фильтрация по валюте
- account.balance — используется в условиях «богатые клиенты», лимиты, VIP-сегмент
- customer.id — PK, уже индексируется как первичный ключ 
- customer.full_name — часто используется для сортировки и отображения списков клиентов

**Предлагаемый индекс:**
- Индекс 1 (на account)
    - Тип: частичный B-tree с INCLUDE 
    - Столбцы: ключ (balance), INCLUDE (customer_id)
    - Условие: WHERE status = 'active' AND currency_code = 'USD'
    - Комментарий:
      - В индекс попадают только строки с активными USD-счетами → компактный и быстрый
      - Условие balance > 1000 использует сортировку по ключу индекса
      - customer_id лежит в INCLUDE, что позволяет делать index-only scan в подзапросе
- Индекс 2 (на customer)
  - Тип: простой B-tree
  - Столбцы: (full_name)
  - Комментарий:
    - Позволяет отдать результат уже отсортированным по full_name без дополнительной сортировки
    - Будет полезен и во многих других запросах со списком клиентов

### Запрос 5
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
**Используемые столбцы:**
- CTE HighRiskCustomers (customer_profile):
  - WHERE: risk_level
  - SELECT: customer_id
- JOIN’ы:
  - customer_profile.customer_id
  - customer_address.customer_id, customer_address.is_primary
  - address.id
- ORDER BY: c.full_name
- SELECT: c.full_name, cp.risk_level, поля из address

**Типичное использование:**
- risk_level — важный аналитический признак (KYC/AML отчёты)
- customer_profile.customer_id — связь 1–1 с customer
- customer_address.customer_id, is_primary — частый кейс (основной адрес клиента)
- customer.full_name — сортировка и отображение клиентов

**Предлагаемый индекс:**
- Индекс 1 (на customer_profile)
  - Тип: составной B-tree
  - Столбцы: (risk_level, customer_id)
  - Комментарий:
    - Ускоряет выборку всех клиентов с risk_level >= 4
    - Наличие customer_id во вторых столбцах позволяет эффективно использовать индекс и в join’ах
- Индекс 2 (на customer_address)
  - Тип: частичный B-tree
  - Столбцы: (customer_id)
  - Условие: WHERE is_primary = TRUE
  - Комментарий:
    - Хранит только основные адреса → размер индекса меньше, доступ быстрее
    - Идеально соответствует условию join’а ca.is_primary = TRUE
- Индекс 3 (на customer)
  - Тип: простой B-tree
  - Столбцы: (full_name)
  - Комментарий:
    - Ускоряет ORDER BY c.full_name
    - Может использоваться многими запросами, где нужен отсортированный список клиентов

## 2. Создание индексов
### Индекс для запроса 1
```sql
CREATE INDEX IF NOT EXISTS idx_customer_status_birth_created
    ON lab01.customer (status, birth_date, created_at DESC);
```
**Тип:** B-дерево

**Почему так:**
- Фильтр по status (равенство) → первый столбец
- Далее по birth_date (условие >=) → второй
- Сортировка по created_at DESC → третий столбец в индексе с DESC, что значительно снижает затраты на ORDER BY ... LIMIT 5

## Индекс для запроса 2
```sql
CREATE INDEX IF NOT EXISTS idx_account_currency
    ON lab01.account (currency_code);
```
**Тип:** B-дерево

**Почему так:**
- GROUP BY currency_code — PostgreSQL может использовать «index-only scan» и группировку по уже отсортированному по валюте набору.
- Индекс по одному столбцу гибкий и пригодится и для других запросов по валюте

## Индекс для запроса 3
```sql
CREATE INDEX IF NOT EXISTS idx_employee_branch
    ON lab01.employee (branch_id);

CREATE INDEX IF NOT EXISTS idx_branch_is_active
    ON lab01.branch (is_active);
```
**Тип:** оба B-дерево

**Почему так:**
- idx_employee_branch:
  - ускоряет JOIN b.id = e.branch_id, так как для каждого филиала быстро находятся все сотрудники
  - полезен для любых отчетов вида «список сотрудников филиала»
- idx_branch_is_active:
  - ускоряет фильтрацию по b.is_active = TRUE
  - особенно полезен, если активных филиалов существенно меньше, чем всех (хорошая селективность)

## Индекс для запроса 4
```sql
CREATE INDEX IF NOT EXISTS idx_account_active_usd_high_balance
    ON lab01.account (balance)
    INCLUDE (customer_id)
    WHERE status = 'active'
      AND currency_code = 'USD';
```
**Тип:** B-дерево, частичный индекс

**Почему так:**
- Запрос интересуется только активными USD-счетами → остальные строки в индекс не попадают, он получается компактным и очень быстрым
- Условие balance > 1000 использует ключ индекса balance (range-condition)
- INCLUDE (customer_id) позволяет делать index-only scan: customer_id читается прямо из индекса
- Фильтры по status и currency_code зашиты в предикат частичного индекса → планировщик сразу берет только нужный «срез» таблицы

## Индекс для запроса 2
```sql
CREATE INDEX IF NOT EXISTS idx_customer_profile_risk
    ON lab01.customer_profile (risk_level, customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_address_primary
    ON lab01.customer_address (customer_id)
    WHERE is_primary = TRUE;

CREATE INDEX IF NOT EXISTS idx_customer_full_name
    ON lab01.customer (full_name);
```
**Тип:** B-дерево, один из них (по customer_address) — частичный

**Почему так:**
- idx_customer_profile_risk:
  - CTE выбирает клиентов по risk_level >= 4, затем нужны customer_id
  - индекс как раз отсортирован по risk_level, а customer_id включен вторым столбцом для эффективной выборки
- idx_customer_address_primary:
  - в JOIN’е фильтр ca.is_primary = TRUE
  - partial-index содержит только основные адреса → меньше размер, быстрее join 
- idx_customer_full_name:
  - для ORDER BY c.full_name без дополнительной сортировки, особенно если запрос часто только читает данные (index-only scans)

## 3. Анализ запросов на модификацию данных
| SELECT из ЛР №2                                           | Индекс                                                                                          | Польза                                                                                                                                                                       |
|-----------------------------------------------------------|-------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Запрос 1 (новые активные клиенты)                        | `idx_customer_status_birth_created (status, birth_date, created_at DESC)`                      | Ускоряет фильтр по `status` и `birth_date`, позволяет отдать клиентов сразу в порядке `created_at DESC` без сортировки, особенно эффективно вместе с `LIMIT 5`.            |
| Запрос 2 (агрегаты по валютам)                           | `idx_account_currency (currency_code)`                                                         | Ускоряет группировку `GROUP BY currency_code`, т.к. строки уже отсортированы по валюте; может использоваться и в других запросах по валюте.                                |
| Запрос 3 (филиалы с > 1 сотрудника)                      | `idx_employee_branch (branch_id)`                                                              | Ускоряет JOIN `branch.id = employee.branch_id` и подсчёт сотрудников в филиале.                                                                                            |
| Запрос 3                                                 | `idx_branch_is_active (is_active)`                                                             | Ускоряет фильтр `WHERE b.is_active = TRUE`, особенно если активных филиалов существенно меньше, чем всех.                                                                  |
| Запрос 4 (клиенты с активным USD-счётом > 1000)          | `idx_account_active_usd_high_balance (balance) INCLUDE (customer_id) WHERE status = 'active' AND currency_code = 'USD'` | Быстро находит активные USD-счета с нужным диапазоном по `balance`, отдаёт `customer_id` прямо из индекса (index-only scan) для подзапроса `IN`.                         |
| Запрос 4                                                 | `idx_customer_full_name (full_name)`                                                          | Ускоряет сортировку `ORDER BY full_name` для найденных клиентов; полезен для любых списков клиентов.                                                                       |
| Запрос 5 (high-risk клиенты с основным адресом)          | `idx_customer_profile_risk (risk_level, customer_id)`                                          | Ускоряет выборку клиентов с `risk_level >= 4` в CTE и последующий JOIN по `customer_id`.                                                                                   |
| Запрос 5                                                 | `idx_customer_address_primary (customer_id) WHERE is_primary = TRUE`                           | Быстро находит основную запись адреса клиента при JOIN `ca.is_primary = TRUE`; индекс меньше, т.к. хранит только основные адреса.                                         |
| Запрос 5                                                 | `idx_customer_full_name (full_name)`                                                          | Ускоряет `ORDER BY c.full_name` в итоговом SELECT; один и тот же индекс используется и в Запросе 4.                                                                        |


## 4. Дополнительные вопросы
### SQL-код всех созданных индексов (CREATE INDEX ...)
- Замедление записей. Каждая вставка/обновление/удаление требует обновить все индексы таблицы
- Рост размера БД. Индекс — это отдельная структура на диске. Индексы на каждый столбец приводит к многократному росту объема
- Планировщик путается. Слишком много индексов усложняют выбор плана выполнения запросов, иногда Postgres выбирает не лучший индекс
- Часть индексов почти никогда не используется. Если по столбцу почти нет фильтров/сортировок, индекс — мертвый груз

### В каких случаях индекс может ухудшить запрос?
- Низкая селективность условия. Тогда Postgres предпочтёт последовательное сканирование таблицы, а попытка использовать индекс даст только лишний overhead (прыжки по диску/страницам)
- Переиндексация и обновления. Если запрос делает массовый UPDATE/DELETE, то общее время работы с учетом обновления индексов может быть выше
- Сложные запросы с ORDER BY и JOIN, не соответствующие структуре индекса. Индекс может только мешать, планировщик иногда выбирает более дорогой план из-за неверной статистики

### Что такое селективность столбца, и как она влияет на полезность индекса?
- Селективность столбца — доля строк, которую выбирает типичное условие в WHERE
- Пример: status = 'blocked', если блокированных клиентов 1% → высокоселективное условие
- Влияние:
  - Высокая селективность (маленькая доля строк) → индекс очень полезен, можно быстро найти небольшое подмножество строк
  - Низкая селективность (условие выбирает почти всё) → индекс мало помогает, т.к. всё равно надо читать почти всю таблицу

### Что такое кардинальность столбца и почему ее нужно учитывать при принятии решения о создании индекса?
- Кардинальность столбца — количество различных значений в этом столбце
- Пример: sex (M/F) → очень низкая кардинальность
- Пример: customer_id или account_number → очень высокая кардинальность (почти все значения уникальны)

Почему важно:
- Связь с селективностью.
  - Высокая кардинальность → при фильтре по конкретному значению выбирается мало строк → индексы эффективны
  - Низкая кардинальность → по одному значению выбирается много строк → индексы часто бесполезны
- Выбор типа и набора столбцов индекса.
  - Столбцы с высокой кардинальностью логично ставить в начало составного индекса
  - Столбцы с очень низкой кардинальностью имеет смысл использовать только в частичных индексах (WHERE sex = 'F') или вообще не индексировать