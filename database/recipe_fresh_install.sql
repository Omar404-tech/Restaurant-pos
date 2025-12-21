-- FRESH INSTALL - Drop and recreate everything

-- Drop existing tables if any
DROP TABLE IF EXISTS production_logs CASCADE;
DROP TABLE IF EXISTS recipe_ingredients CASCADE;

-- Drop column if exists
ALTER TABLE items DROP COLUMN IF EXISTS is_recipe;

-- Delete category if exists
DELETE FROM categories WHERE code = 'CAT-RECIPE';

-- Now create everything fresh

-- 1. Add Recipe category
INSERT INTO categories (code, name, name_ar, description, is_active, sort_order)
VALUES ('CAT-RECIPE', 'Recipes', 'ريسبي', 'المنتجات المصنعة', true, 100);

-- 2. Add is_recipe column
ALTER TABLE items ADD COLUMN is_recipe BOOLEAN DEFAULT false;

-- 3. Create recipe_ingredients table
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

-- 4. Create production_logs table
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

-- 5. Enable RLS
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_logs ENABLE ROW LEVEL SECURITY;

-- 6. Create policies
CREATE POLICY "allow_all_recipe_ingredients" ON recipe_ingredients FOR ALL USING (true);
CREATE POLICY "allow_all_production_logs" ON production_logs FOR ALL USING (true);

-- 7. Verify
SELECT 'DONE' as status, code, name_ar FROM categories WHERE code = 'CAT-RECIPE';
