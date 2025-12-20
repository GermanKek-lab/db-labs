-- 1) Таблица счетов
CREATE TABLE IF NOT EXISTS accounts (
    id        BIGSERIAL PRIMARY KEY,
    owner     TEXT NOT NULL,
    balance   NUMERIC(18,2) NOT NULL CHECK (balance >= 0),
    currency  TEXT NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION transfer_money(
    p_from_id   BIGINT,
    p_to_id     BIGINT,
    p_amount    NUMERIC(18,2),
    p_currency  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_balance NUMERIC(18,2);
    v_to_currency  TEXT;
    v_from_currency TEXT;
    v_lock_a BIGINT;
    v_lock_b BIGINT;
BEGIN
    IF p_from_id = p_to_id THEN
        RAISE EXCEPTION 'from_id equals to_id';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'amount must be > 0';
    END IF;

    v_lock_a := LEAST(p_from_id, p_to_id);
    v_lock_b := GREATEST(p_from_id, p_to_id);

    PERFORM pg_advisory_xact_lock(v_lock_a);
    PERFORM pg_advisory_xact_lock(v_lock_b);
    SELECT balance, currency
      INTO v_from_balance, v_from_currency
      FROM accounts
     WHERE id = p_from_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'from account % not found', p_from_id;
    END IF;

    SELECT currency
      INTO v_to_currency
      FROM accounts
     WHERE id = p_to_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'to account % not found', p_to_id;
    END IF;

    IF p_currency IS NOT NULL THEN
        IF v_from_currency <> p_currency OR v_to_currency <> p_currency THEN
            RAISE EXCEPTION 'currency mismatch: from=%, to=%, expected=%',
                v_from_currency, v_to_currency, p_currency;
        END IF;
    ELSE
        IF v_from_currency <> v_to_currency THEN
            RAISE EXCEPTION 'currency mismatch: from=%, to=%', v_from_currency, v_to_currency;
        END IF;
    END IF;

    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'insufficient funds: balance=%, amount=%', v_from_balance, p_amount;
    END IF;

    UPDATE accounts
       SET balance = balance - p_amount
     WHERE id = p_from_id;

    UPDATE accounts
       SET balance = balance + p_amount
     WHERE id = p_to_id;
END;
$$;