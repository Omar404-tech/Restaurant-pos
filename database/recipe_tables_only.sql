ALTER TABLE items ADD COLUMN IF NOT EXISTS is_recipe BOOLEAN DEFAULT false;

CREATE TABLE recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  ingredient_item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
  quantity DECIMAL(10,3) NOT NULL,
  unit_id UUID REFERENCES units(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE production_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_number VARCHAR(50) UNIQUE NOT NULL,
  recipe_item_id UUID NOT NULL REFERENCES items(id),
  branch_id UUID NOT NULL REFERENCES branches(id),
  quantity DECIMAL(10,3) NOT NULL,
  notes TEXT,
  produced_by UUID REFERENCES users(id),
  produced_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_all_recipe_ingredients" ON recipe_ingredients FOR ALL USING (true);
CREATE POLICY "allow_all_production_logs" ON production_logs FOR ALL USING (true);
