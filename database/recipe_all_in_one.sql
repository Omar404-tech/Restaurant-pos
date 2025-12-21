-- =============================================
-- RECIPE SYSTEM - RUN THIS ENTIRE FILE AT ONCE
-- =============================================

-- 1. Add Recipe category
INSERT INTO categories (id, code, name, name_ar, description, is_active, sort_order)
VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'CAT-RECIPE',
  'Recipes',
  'ريسبي',
  'المنتجات المصنعة من مكونات متعددة',
  true,
  100
)
ON CONFLICT (code) DO NOTHING;

-- 2. Add is_recipe column to items
ALTER TABLE items ADD COLUMN IF NOT EXISTS is_recipe BOOLEAN DEFAULT false;

-- 3. Create recipe_ingredients table
CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  ingredient_item_id UUID NOT NULL REFERENCES items(id) ON DELETE RESTRICT,
  quantity DECIMAL(10,3) NOT NULL CHECK (quantity > 0),
  unit_id UUID REFERENCES units(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(recipe_item_id, ingredient_item_id)
);

-- 4. Create production_logs table
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

-- 5. Create indexes
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient ON recipe_ingredients(ingredient_item_id);
CREATE INDEX IF NOT EXISTS idx_production_logs_recipe ON production_logs(recipe_item_id);
CREATE INDEX IF NOT EXISTS idx_production_logs_branch ON production_logs(branch_id);

-- 6. Enable RLS
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_logs ENABLE ROW LEVEL SECURITY;

-- 7. RLS Policies
CREATE POLICY "recipe_ingredients_all" ON recipe_ingredients FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "production_logs_all" ON production_logs FOR ALL USING (true) WITH CHECK (true);

-- 8. Verify
SELECT 'Category' as test, code, name_ar FROM categories WHERE code = 'CAT-RECIPE';
