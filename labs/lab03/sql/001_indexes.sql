-- Индецс 1
CREATE INDEX IF NOT EXISTS idx_customer_status_birth_created
    ON lab01.customer (status, birth_date, created_at DESC);

-- Индецс 2
CREATE INDEX IF NOT EXISTS idx_account_currency
    ON lab01.account (currency_code);

-- Индецс 3
CREATE INDEX IF NOT EXISTS idx_employee_branch
    ON lab01.employee (branch_id);

CREATE INDEX IF NOT EXISTS idx_branch_is_active
    ON lab01.branch (is_active);

-- Индецс 4
CREATE INDEX IF NOT EXISTS idx_account_active_usd_high_balance
    ON lab01.account (balance)
    INCLUDE (customer_id)
    WHERE status = 'active'
      AND currency_code = 'USD';

-- Индекс 5
CREATE INDEX IF NOT EXISTS idx_customer_profile_risk
    ON lab01.customer_profile (risk_level, customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_address_primary
    ON lab01.customer_address (customer_id)
    WHERE is_primary = TRUE;

CREATE INDEX IF NOT EXISTS idx_customer_full_name
    ON lab01.customer (full_name);