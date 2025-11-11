SET search_path TO lab01, public;

/*
Заполнить таблицы начальными данными для тестирования и демонстрации работы БД
*/

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

/*
Корректировка баланса счета
Контекст: Пополнение счета клиента на сумму 1000.00 USD
Ограничения и условия:
    - Счет должен быть активным
    - Баланс должен быть скорректирован только для указанного номера счета
*/
UPDATE
    account
SET
    balance = balance + 1000.00
WHERE
    account_number = '40817810000010000001'
AND
    status = 'active';

/*
Обновление статуса KYC для клиентов с высоким уровнем риска
Контекст: Клиенты с уровнем риска 3 и выше требуют пересмотра их KYC статуса
Ограничения и условия:
    - Обновление должно происходить только для клиентов с текущим статусом 'verified'
    - Ограничение уровень риска должно быть 3 и выше
*/
UPDATE
    customer_profile
SET
    kyc_status = 'pending_review', updated_at = NOW()
WHERE
    risk_level >= 3
AND
    kyc_status = 'verified';

/*
Удаление адреса, не связанного с активными клиентами
Контекст: Адрес в США (id = 104) больше не используется и не связан с активными клиентами
Ограничения и условия:
    - Адрес должен быть удален только если он не связан с активными клиентами
    - Удаление должно быть безопасным и не нарушать целостность данных (либо внешние ключи должны быть настроены на автоматическое удаление)
*/
DELETE FROM address WHERE id = 104 AND country = 'США';