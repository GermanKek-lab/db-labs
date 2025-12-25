# Отчёт по Лабораторной работе №6: Партиционирование и шардирование

* **Схема БД**: lab01
* **СУБД**: PostgreSQL 16

## 1. Партиционирование
### Выбор таблицы
**Выбранная таблица:** lab01.txn
Почему подходит:
1. Это журнал операций (append-only модель)
2. Частые запросы обычно идут по периоду или по аккаунту
3. Старые данные часто архивируются/удаляются

**Стратегия:** RANGE (posted_at)
Почему RANGE:
- естественная временная ось
- упрощает удаление старых данных
- улучшает план запросов: pruning (не читает лишние партиции)

### Создание партиционированной таблицы
#### Создаём новую таблицу txn_new (partitioned)
```sql
create table lab01.txn_new (
    id              bigint      not null,
    account_id      bigint      not null,
    operation_type  text        not null,
    amount          numeric(14,2) not null,
    currency_code   text        not null,
    posted_at       timestamp   not null,
    value_date      timestamp   null,
    description     text        null,
    external_ref    text        null
) partition by range (posted_at);
```

#### Создаём 3 партиции + default
```sql
create table lab01.txn_new_2025_10
partition of lab01.txn_new
for values from ('2025-10-01') to ('2025-11-01');

create table lab01.txn_new_2025_11
partition of lab01.txn_new
for values from ('2025-11-01') to ('2025-12-01');

create table lab01.txn_new_2025_12
partition of lab01.txn_new
for values from ('2025-12-01') to ('2026-01-01');

create table lab01.txn_new_default
partition of lab01.txn_new
default;
```

#### id + partition key
```sql
create index concurrently if not exists idx_txn_new_2025_10_id_posted
on lab01.txn_new_2025_10 (id, posted_at);

create index concurrently if not exists idx_txn_new_2025_11_id_posted
on lab01.txn_new_2025_11 (id, posted_at);

create index concurrently if not exists idx_txn_new_2025_12_id_posted
on lab01.txn_new_2025_12 (id, posted_at);

create index concurrently if not exists idx_txn_new_default_id_posted
on lab01.txn_new_default (id, posted_at);
```

#### Настройка копирования
**Цель:** пока идёт миграция, новые вставки в старую таблицу txn должны автоматически попадать и в txn_new
```sql
create or replace function lab01.trg_txn_mirror_to_partitioned()
returns trigger
language plpgsql
as $$
begin
    insert into lab01.txn_new (
        id, account_id, operation_type, amount, currency_code,
        posted_at, value_date, description, external_ref
    )
    values (
        new.id, new.account_id, new.operation_type, new.amount, new.currency_code,
        new.posted_at, new.value_date, new.description, new.external_ref
    );

    return new;
end;
$$;

drop trigger if exists trg_txn_mirror on lab01.txn;

create trigger trg_txn_mirror
after insert on lab01.txn
for each row
execute function lab01.trg_txn_mirror_to_partitioned();
```

#### Проверка dual-write
```sql
-- вставляем тестовую операцию в СТАРУЮ таблицу
insert into lab01.txn (id, account_id, operation_type, amount, currency_code, posted_at, description)
values (999999, 601, 'deposit', 1.00, 'USD', now(), 'dual-write check');

-- проверяем, что появилась в НОВОЙ (и попала в нужную партицию или default)
select count(*) as cnt_old from lab01.txn where id = 999999;
select count(*) as cnt_new from lab01.txn_new where id = 999999;
```
**Ожидаемо:** cnt_old = 1, cnt_new = 1
**Фактически:** фактический резултат совпал с ожидаемым

#### Перенос данных
**Цель:** перелить исторические данных из txn в txn_new, не ломая вставки, которые происходят в реальном времени
```sql
insert into lab01.txn_new (
    id, account_id, operation_type, amount, currency_code,
    posted_at, value_date, description, external_ref
)
select
    id, account_id, operation_type, amount, currency_code,
    posted_at, value_date, description, external_ref
from lab01.txn
where posted_at < (now() - interval '5 seconds');
```
**Ожидаемо:** количество строк в txn_new станет = количеству в txn
**Фактически:** правильно перенеслось, но бнаружено дублирование записи 999999 из-за пересечения окна backfill с периодом, когда уже работал триггер dual-write<br>

### Восстановление индексов, constraint
**Цель:** Восстановить на новой партиционированной таблице lab01.txn_new все необходимые ограничения целостности и уникальности (PK/UNIQUE/FK/CHECK), которые были в исходной таблице lab01.txn

#### Уникальные индексы на партициях
```sql
create unique index concurrently if not exists uq_txn_new_2025_10_id_posted
on lab01.txn_new_2025_10 (id, posted_at);

create unique index concurrently if not exists uq_txn_new_2025_11_id_posted
on lab01.txn_new_2025_11 (id, posted_at);

create unique index concurrently if not exists uq_txn_new_2025_12_id_posted
on lab01.txn_new_2025_12 (id, posted_at);

create unique index concurrently if not exists uq_txn_new_default_id_posted
on lab01.txn_new_default (id, posted_at);
```

#### PK на родительскую таблицу (он создаст “metadata constraint” поверх партиций)
```sql
alter table lab01.txn_new
add constraint pk_txn_new_id_posted primary key (id, posted_at);
```

#### FK и CHECK — “NOT VALID → VALIDATE”
```sql
alter table lab01.txn_new
add constraint fk_txn_new_account
foreign key (account_id) references lab01.account(id)
on delete cascade
not valid;

alter table lab01.txn_new
add constraint fk_txn_new_currency
foreign key (currency_code) references lab01.currency(code)
on delete restrict
not valid;

alter table lab01.txn_new
validate constraint fk_txn_new_account;

alter table lab01.txn_new
validate constraint fk_txn_new_currency;
```

### Проверка и удаление старой таблицы
#### Проверка идентичности данных
```sql
select count(*) as cnt_old, sum(id) as sum_id_old from lab01.txn;
select count(*) as cnt_new, sum(id) as sum_id_new from lab01.txn_new;

select
  min(posted_at) as min_posted_old,
  max(posted_at) as max_posted_old
from lab01.txn;

select
  min(posted_at) as min_posted_new,
  max(posted_at) as max_posted_new
from lab01.txn_new;
```

#### Переключение записи на новую таблицу
Узнаём имя sequence для старого txn.id
```sql
begin;

lock table lab01.txn in access exclusive mode;
lock table lab01.txn_new in access exclusive mode;

alter table lab01.txn_new
alter column id set default nextval('lab01.txn_id_seq');

alter sequence lab01.txn_id_seq
owned by lab01.txn_new.id;

alter table lab01.txn rename to txn_old;
alter table lab01.txn_new rename to txn;

commit;
```

#### Удаляем старое и триггеры
```sql
drop trigger if exists trg_txn_mirror on lab01.txn_old;
drop function if exists lab01.trg_txn_mirror_to_partitioned();

drop table lab01.txn_old;
```

### Доп вопросы
#### Что такое партиция с точки зрения postgres?
Партиция — это обычная физическая таблица, которая является дочерней для родительской partitioned-таблицы
Родитель хранит только правила маршрутизации, а данные лежат в дочерних таблицах

Чем полезны партиции? Какой в них смысл?
1.	Partition pruning: запрос по времени читает только нужные партиции
2.	Ускорение обслуживания: VACUUM/ANALYZE/REINDEX по частям
3.	Архивация: старое проще удалить через DROP TABLE partition
4.	Локальность индексов: индексы меньше и быстрее внутри партиции

Что лучше? Периодически удалять данные или дропать ненужные партиции? Почему?
Лучше DROP партиций, потому что:
- DELETE оставляет мусор -> нужен VACUUM, нагрузка на WAL
- DROP TABLE partition — быстрая операция метаданных, минимальная нагрузка
