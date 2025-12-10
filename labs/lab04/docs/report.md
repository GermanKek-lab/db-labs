# Отчёт по Лабораторной работе №4: Функции и триггеры

* **Схема БД**: lab01
* **СУБД**: PostgreSQL 16

## 1. Проблемы параллелизма
### Грязное чтение (Dirty Read)
**Цель:** проверить, можно ли в PostgreSQL прочитать незакоммиченные изменения другой транзакции<br>
Сессия 1:
```sql
BEGIN;

UPDATE account
SET balance = balance + 100
WHERE id = 601;

SELECT balance
FROM account
WHERE id = 601;
-- пример: 1600.00
```

Сессия 2:
```sql
BEGIN;

SELECT balance
FROM account
WHERE id = 601;
-- пример: 1500.00 (старое значение, без незакоммиченного UPDATE)

COMMIT;
```
* Ожидание при наличии Dirty Read: Сессия 2 увидит 1600.00
* Фактический результат: Сессия 2 видит старое значение (1500.00)

**Вывод:** Грязное чтение в PostgreSQL невозможно, потому что Postgres не показывает незакоммиченные версии строк<br>
**Способы решения:** Postgre уже защищает от Dirty Read по умолчанию

### Неповторяющееся чтение (Non-repeatable Read)
**Цель:** показать, что одно и то же условие в рамках одной транзакции может возвращать разные данные<br>
Сессия 1:
```sql
BEGIN;

SELECT balance
FROM account
WHERE id = 601;
-- пример: 1500.00
```
Сессия 2:
```sql
BEGIN;

UPDATE account
SET balance = balance + 100
WHERE id = 601;

COMMIT;
```
Сессия 1 (продолжение):
```sql
SELECT balance
FROM account
WHERE id = 601;
-- теперь: 1600.00

COMMIT;
```
* Ожидание: значение может поменяться между чтениями
* Фактический результат: первое чтение — 1500.00, второе — 1600.00

**Вывод:** При уровне READ COMMITTED в Postgre возможна аномалия неповторяющегося чтения<br>
**Способы решения:** SELECT ... FOR UPDATE — блокирует выбранные строки для изменений другими транзакциями до конца текущей

### Фантомное чтение (Phantom Read)
**Цель:** показать, что между двумя чтениями множества строк могут появиться новые строки фантомы<br>
Сессия 1:
```sql
BEGIN;

SELECT COUNT(*)
FROM account
WHERE status = 'active';
-- пример: 4
```

Сессия 2:
```sql
BEGIN;

INSERT INTO account (id, account_number, customer_id, product_id, currency_code, status, balance)
VALUES (700, '40817810000010000700', 401, 503, 'USD', 'active', 10.00);

COMMIT;
```

Сессия 1 (продолжение):
```sql
SELECT COUNT(*)
FROM account
WHERE status = 'active';
-- теперь: 5

COMMIT;
```
* Ожидание: количество строк может измениться
* Фактический результат: первый COUNT — 4, второй — 5

**Вывод:** При READ COMMITTED в Postgre возможна аномалия фантомного чтения<br>
**Способы решения:** REPEATABLE READ в Postgre фантомов почти нет, так как транзакция работает со «старым» снимком данных

### Аномалия сериализации (Write Skew / Lost Update)
**Цель:** показать потерянное обновление при шаблоне прочитал -> посчитал -> записал константу<br>
Сессия 1:
```sql
BEGIN;

SELECT balance
FROM account
WHERE id = 601;
-- 1500.00

-- приложение считает новый баланс = 1400.00
UPDATE account
SET balance = 1400.00
WHERE id = 601;

COMMIT
```

Сессия 2 (почти параллельно, до коммита 1):
```sql
BEGIN;

SELECT balance
FROM account
WHERE id = 601;
-- тоже видит 1500.00

-- приложение тоже считает новый баланс = 1400.00
UPDATE account
SET balance = 1400.00
WHERE id = 601;

COMMIT;
```
* Ожидание: логически баланс должен стать 1300.00 (две операции по -100)
* Фактический результат: итог 1400.00, одно изменение потеряно

**Вывод:** Возникает lost update<br>
**Способы решения:** уровнь SERIALIZABLE или логикой оптимистичных блокировок

### Какую из перечисленных проблем невозможно воспроизвести в postgresql при стандартных настройках? Почему?
> Невозможно воспроизвести грязное чтение (Dirty Read), потому что:
>* PostgreSQL не поддерживает уровень изоляции READ UNCOMMITTED
>* при READ COMMITTED и выше читатели видят только закоммиченные версии строк

### Блокировки
**Цель**: увидеть, как конфликтующие операции блокируют строку и как это отражается в pg_locks
Сессия 1
```sql
BEGIN;

UPDATE lab01.account
SET balance = balance + 100
WHERE id = 601;
```

Сессия 2
```sql
BEGIN;

UPDATE lab01.account
SET balance = balance + 50
WHERE id = 601;
```

Пока второй UPDATE висит, смотрим pg_locks в сессии 3:
```sql
SELECT
    l.pid,
    a.usename,
    a.query,
    l.locktype,
    l.mode,
    l.granted,
    l.relation::regclass AS rel,
    l.page,
    l.tuple
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.relation = 'lab01.account'::regclass
ORDER BY l.granted DESC, l.pid;
```

* Ожидание:
	* для Сессии 1 — блокировка с granted = true
	* для Сессии 2 — блокировка с granted = false (ожидание)
* Фактический результат:
  * видим одну строку с mode = RowExclusiveLock, granted = true (Сессия 1)
  * другую с granted = false (Сессия 2)

**Вывод:** pg_locks позволяет диагностировать, кто кого блокирует и на каком типе ресурса 

> Что видно 
> * У процесса из первого сеанса 
>   * есть RowExclusiveLock (строчная блокировка) на строку в lab01.account 
>   * флаг granted = true
> * У процесса из второго сеанса 
>   * RowExclusiveLock на тот же объект 
>   * granted = false — блокировка ожидается

### Advisory-блокировки
**Цель:** Синхронизировать логически конфликтующие операции с помощью pg_advisory_lock, чтобы два перевода с одним и тем же счётом не выполнялись параллельно

Сеанс 1
```sql
BEGIN;

SELECT pg_advisory_lock(hashtext('transfer:601:602'));

UPDATE lab01.account
SET balance = balance - 100
WHERE id = 601;

INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description)
VALUES (9001, 601, 'transfer_out', -100, 'USD', 'Transfer to 602');

UPDATE lab01.account
SET balance = balance + 100
WHERE id = 602;

INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description)
VALUES (9002, 602, 'transfer_in', 100, 'USD', 'Transfer from 601');

SELECT pg_advisory_unlock(hashtext('transfer:601:602'));

COMMIT;
```

Сеанс 2
```sql
BEGIN;

SELECT pg_advisory_lock(hashtext('transfer:601:602'));

SELECT pg_advisory_unlock(hashtext('transfer:601:602'));
COMMIT;
```

## 2. Хранимые процедуры и функции
### Создание хранимой процедуры и функции
**Цель:** Сделать функцию, которая по customer_id возвращает суммарный баланс по всем его активным счетам
Функция
```sql
CREATE OR REPLACE FUNCTION lab01.fn_customer_total_balance(p_customer_id bigint)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric := 0;
BEGIN
    SELECT COALESCE(SUM(balance), 0)
    INTO v_total
    FROM lab01.account
    WHERE customer_id = p_customer_id
      AND status = 'active';

    RETURN v_total;
END;
$$;
```
Хранимая процедура
```sql
CREATE SEQUENCE IF NOT EXISTS lab01.txn_id_seq;

CREATE OR REPLACE PROCEDURE lab01.sp_transfer_between_accounts(
    p_from_account_id bigint,
    p_to_account_id   bigint,
    p_amount          numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_balance numeric;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;

    SELECT balance INTO v_from_balance
    FROM lab01.account
    WHERE id = p_from_account_id
      AND status = 'active'
    FOR UPDATE;

    IF v_from_balance IS NULL THEN
        RAISE EXCEPTION 'Source account not found or inactive';
    END IF;

    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds: balance=%, amount=%',
            v_from_balance, p_amount;
    END IF;

    UPDATE lab01.account
    SET balance = balance - p_amount
    WHERE id = p_from_account_id;

    UPDATE lab01.account
    SET balance = balance + p_amount
    WHERE id = p_to_account_id
      AND status = 'active';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target account not found or inactive';
    END IF;

    INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description)
    VALUES (nextval('lab01.txn_id_seq'), p_from_account_id, 'transfer_out', -p_amount, 'USD', 'Stored procedure transfer');

    INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description)
    VALUES (nextval('lab01.txn_id_seq'), p_to_account_id, 'transfer_in', p_amount, 'USD', 'Stored procedure transfer');
END;
$$;
```

В чём разница между функцией и процедурой
1. Функция
* Всегда что-то возвращает
* Можно использовать внутри выражени: SELECT fn(...), WHERE fn(...) > 0, ...
* Предназначена скорее для вычислений
* В PostgreSQL есть ограничения на управление транзакциями внутри функций
2. Процедура
* Может ничего не возвращать
* Вызывается через CALL
* Ориентирована на действия и побочные эффекты
* В новых версиях PostgreSQL процедуры отдельнее от функций и потенциально могут использоваться в разных транзакционных сценариях

## Циклы в процедурах
### Процедура с циклом
**Цель:** Пройти по всем активным кредитам циклом, для каждого кредита посчитать дельту и выполнить отдельный UPDATE
```sql
CREATE OR REPLACE PROCEDURE lab01.sp_apply_monthly_interest_loop()
LANGUAGE plpgsql
AS $$
DECLARE
    r_loan RECORD;
    v_delta numeric;
BEGIN
    FOR r_loan IN
        SELECT id, principal_amount, annual_rate_pct
        FROM lab01.loan
        WHERE status = 'active'
    LOOP
        v_delta := r_loan.principal_amount * (r_loan.annual_rate_pct / 12.0 / 100.0);

        UPDATE lab01.loan
        SET principal_amount = principal_amount + v_delta
        WHERE id = r_loan.id;
    END LOOP;
END;
$$;
```
* Ожидание: для каждой строки loan со status = 'active' поле principal_amount увеличится на рассчитанную v_delta
* Фактический результат: при запуске процедуры на тестовых данных каждая активная запись получает ожидаемую надбавку

**Вывод:** Такой подход прост и понятен, но неэффективен при большом количестве строк: на каждый кредит выполняется отдельный UPDATE

### Процедура без цикла
**Цель:** Сделать то же самое одним UPDATE по условию, без явного цикла
```sql
CREATE OR REPLACE PROCEDURE lab01.sp_apply_monthly_interest_set_based()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE lab01.loan
    SET principal_amount = principal_amount
        + principal_amount * (annual_rate_pct / 12.0 / 100.0)
    WHERE status = 'active';
END;
$$;
```
* Ожидание: результат по данным должен совпадать с процедурой с циклом — все активные кредиты увеличиваются на ту же величину
* Фактический результат: при одинаковом исходном состоянии таблицы loan после выполнения обеих процедур значения principal_amount совпадают

**Вывод:** Этот вариант концептуально проще для движка и лучше подходит для обработки больших объёмов данных

> Сравнение подходов и выводы по производительности
> Цикл
> * Плюсы:
>   * легко добавить сложную, индивидуальную логику для каждой строки
>   * удобно пошагово отлаживать 
> * Минусы:
> * большое количество отдельных UPDATE -> лишние накладные расходы
> * хуже масштабируется при большом числе строк 
> 
> Хранимая процедура 
> * Плюсы:
>   * один план выполнения, одна команда UPDATE
>   * оптимально использует возможности SQL-движка
>   * хорошо масштабируется на тысячи и миллионы строк 
> * Минусы:
>   * сложнее реализовать очень разветвлённую и разную для каждой строки логику

## 3. Триггеры
### Создание и тестирование триггера
### AFTER триггер
**Цель:** Автоматически обновлять поле balance в lab01.account при вставке новой операции в lab01.txn
Триггерная функция
```sql
CREATE OR REPLACE FUNCTION lab01.trg_update_account_balance()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_sign numeric := 1;
BEGIN
    IF NEW.operation_type = 'withdrawal'
       OR NEW.operation_type = 'transfer_out' THEN
        v_sign := -1;
    ELSIF NEW.operation_type = 'deposit'
       OR NEW.operation_type = 'transfer_in' THEN
        v_sign := 1;
    ELSE
        v_sign := 1;
    END IF;

    UPDATE lab01.account
    SET balance = COALESCE(balance, 0) + v_sign * NEW.amount
    WHERE id = NEW.account_id;

    RETURN NEW;
END;
$$;
```

Триггер
```sql
CREATE TRIGGER trg_txn_update_balance
AFTER INSERT ON lab01.txn
FOR EACH ROW
EXECUTE FUNCTION lab01.trg_update_account_balance();
```

### Тестирование тригера
Задаём стартовый баланс
```sql
UPDATE lab01.account
SET balance = 1000.00
WHERE id = 601;

SELECT balance FROM lab01.account WHERE id = 601;
```

Проверка пополнения
```sql
INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description)
VALUES (9100, 601, 'deposit', 200.00, 'USD', 'Test trigger: deposit');

SELECT balance FROM lab01.account WHERE id = 601;
```

Проверка списания 
```sql
INSERT INTO lab01.txn (id, account_id, operation_type, amount, currency_code, description)
VALUES (9101, 601, 'withdrawal', 300.00, 'USD', 'Test trigger: withdrawal');

SELECT balance FROM lab01.account WHERE id = 601;
```

### Циклический триггер
**Цель:** Смоделировать ситуацию бесконечной взаимной реакции триггеров между двумя таблицами
Создание тестовых таблиц
```sql
CREATE TABLE lab01.test_a (
    id   bigint PRIMARY KEY,
    val  integer
);

CREATE TABLE lab01.test_b (
    id   bigint PRIMARY KEY,
    val  integer
);

INSERT INTO lab01.test_a (id, val) VALUES (1, 10);
INSERT INTO lab01.test_b (id, val) VALUES (1, 20);
```

Триггер A → B
```sql
CREATE OR REPLACE FUNCTION lab01.trg_a_to_b()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE lab01.test_b
    SET val = val + 1
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_a_after_update
AFTER UPDATE ON lab01.test_a
FOR EACH ROW
EXECUTE FUNCTION lab01.trg_a_to_b();
```

Триггер B → A
```sql
CREATE OR REPLACE FUNCTION lab01.trg_b_to_a()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE lab01.test_a
    SET val = val + 1
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_b_after_update
AFTER UPDATE ON lab01.test_b
FOR EACH ROW
EXECUTE FUNCTION lab01.trg_b_to_a();
```
Запуск цикла
```sql
UPDATE lab01.test_a
SET val = val + 1
WHERE id = 1;
```

Дальше цепочка такая:
1. UPDATE test_a → срабатывает trg_a_after_update → UPDATE test_b
2. UPDATE test_b → срабатывает trg_b_after_update → UPDATE test_a
3. И так по кругу, пока не сработает защита PostgreSQL

>**как PostgreSQL обрабатывает такую ситуацию?**
> * PostgreSQL не выявляет цикл заранее, он просто рекурсивно выполняет триггеры
> * Когда глубина вызовов превышает внутренний лимит, возникает ошибка
> * Вся транзакция откатывается, данные в test_a и test_b возвращаются к исходному состоянию
> * Пользователь получает ошибку, и для продолжения работы нужно выполнить ROLLBACK и потом исправить логику триггеров

## 4. Низкоуровневое хранение данных в PostgreSQL
**Цель:** Выбрать одну из таблиц схемы и получить содержимое одной страницы в сыром виде. В качестве таблицы использую account
Получить блок 0 таблицы lab01.account:
```sql
SELECT get_raw_page('lab01.account', 0);
```
Анализ заголовка страницы через page_header
```sql
SELECT * FROM page_header(get_raw_page('lab01.account', 0));
``` 

* Ожидаемый результат: запрос возвращает одну строку с набором служебных полей заголовка страницы
* Фактический результат:

| lsn  | checksum | flags | lower  |  upper |  special |  pagesize | version  |  prune_xid |
|---|----------|-------|---|---|---|---|---|---|
|  0/17C8B1A8  | 0        | 0     |  44 | 7800  |  8192 | 8192  |  4 | 0  |

> **Что значат поля в полученной таблице?**
> * lsn — позиция в WAL с последней модификацией страницы 
> * checksum — контрольная сумма страницы
> * flags — флаги состояния страницы 
> * lower — смещение конца массива item-дескрипторов
> * upper — смещение начала свободного места 
> * special — начало special space
> * pagesize — размер страницы
> * version — версия формата страницы
> * prune_xid — XID последней очистки страницы в рамках MVCC
