-- Step 4: Create production_logs table
CREATE TABLE IF NOT EXISTS production_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_number VARCHAR(50) UNIQUE NOT NULL,
  recipe_item_id UUID NOT NULL REFERENCES items(id),
  branch_id UUID NOT NULL REFERENCES branches(id),
  quantity DECIMAL(10,3) NOT NULL CHECK (quantity > 0),
  notes TEXT,
  produced_by UUID REFERENCES users(id),
  produced_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
