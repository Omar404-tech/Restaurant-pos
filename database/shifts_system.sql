-- =====================================================
-- CASHIER SHIFTS SYSTEM
-- =====================================================

-- 1. Create cashier_shifts table
CREATE TABLE IF NOT EXISTS cashier_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_number VARCHAR(50) UNIQUE NOT NULL,
  cashier_id UUID NOT NULL REFERENCES users(id),
  branch_id UUID NOT NULL REFERENCES branches(id),
  start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_time TIMESTAMPTZ,
  opening_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  closing_amount DECIMAL(10,2),
  expected_amount DECIMAL(10,2),
  cash_sales DECIMAL(10,2) DEFAULT 0,
  card_sales DECIMAL(10,2) DEFAULT 0,
  total_sales DECIMAL(10,2) DEFAULT 0,
  orders_count INTEGER DEFAULT 0,
  difference DECIMAL(10,2),
  status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  notes TEXT,
  closed_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Add shift_id to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES cashier_shifts(id);

-- 3. Create index for performance
CREATE INDEX IF NOT EXISTS idx_cashier_shifts_cashier ON cashier_shifts(cashier_id);
CREATE INDEX IF NOT EXISTS idx_cashier_shifts_branch ON cashier_shifts(branch_id);
CREATE INDEX IF NOT EXISTS idx_cashier_shifts_status ON cashier_shifts(status);
CREATE INDEX IF NOT EXISTS idx_cashier_shifts_start_time ON cashier_shifts(start_time);
CREATE INDEX IF NOT EXISTS idx_orders_shift ON orders(shift_id);

-- 4. Enable RLS
ALTER TABLE cashier_shifts ENABLE ROW LEVEL SECURITY;

-- 5. Create policies
DROP POLICY IF EXISTS "allow_all_cashier_shifts" ON cashier_shifts;
CREATE POLICY "allow_all_cashier_shifts" ON cashier_shifts FOR ALL USING (true);

-- 6. Create function to get open shift for a cashier
CREATE OR REPLACE FUNCTION get_open_shift(p_cashier_id UUID, p_branch_id UUID)
RETURNS UUID AS $$
DECLARE
  v_shift_id UUID;
BEGIN
  SELECT id INTO v_shift_id
  FROM cashier_shifts
  WHERE cashier_id = p_cashier_id
    AND branch_id = p_branch_id
    AND status = 'open'
  ORDER BY start_time DESC
  LIMIT 1;
  
  RETURN v_shift_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Create function to close shift and calculate totals
CREATE OR REPLACE FUNCTION close_shift(
  p_shift_id UUID,
  p_closing_amount DECIMAL,
  p_closed_by UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_cash_sales DECIMAL;
  v_card_sales DECIMAL;
  v_total_sales DECIMAL;
  v_orders_count INTEGER;
  v_opening_amount DECIMAL;
  v_expected_amount DECIMAL;
  v_difference DECIMAL;
BEGIN
  -- Get opening amount
  SELECT opening_amount INTO v_opening_amount
  FROM cashier_shifts WHERE id = p_shift_id;
  
  -- Calculate sales from orders in this shift
  SELECT 
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN payment_method != 'cash' THEN total_amount ELSE 0 END), 0),
    COALESCE(SUM(total_amount), 0),
    COUNT(*)
  INTO v_cash_sales, v_card_sales, v_total_sales, v_orders_count
  FROM orders
  WHERE shift_id = p_shift_id
    AND status NOT IN ('cancelled');
  
  -- Calculate expected and difference
  v_expected_amount := v_opening_amount + v_cash_sales;
  v_difference := p_closing_amount - v_expected_amount;
  
  -- Update shift
  UPDATE cashier_shifts SET
    end_time = NOW(),
    closing_amount = p_closing_amount,
    expected_amount = v_expected_amount,
    cash_sales = v_cash_sales,
    card_sales = v_card_sales,
    total_sales = v_total_sales,
    orders_count = v_orders_count,
    difference = v_difference,
    status = 'closed',
    closed_by = p_closed_by,
    notes = COALESCE(p_notes, notes),
    updated_at = NOW()
  WHERE id = p_shift_id;
  
  RETURN json_build_object(
    'success', true,
    'cash_sales', v_cash_sales,
    'card_sales', v_card_sales,
    'total_sales', v_total_sales,
    'orders_count', v_orders_count,
    'expected_amount', v_expected_amount,
    'difference', v_difference
  );
END;
$$ LANGUAGE plpgsql;

-- 8. Verify
SELECT 'SHIFTS_SYSTEM_INSTALLED' as status;
