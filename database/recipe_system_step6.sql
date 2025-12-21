-- Step 6: Enable RLS and create policies
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for recipe_ingredients
DROP POLICY IF EXISTS "recipe_ingredients_select" ON recipe_ingredients;
DROP POLICY IF EXISTS "recipe_ingredients_insert" ON recipe_ingredients;
DROP POLICY IF EXISTS "recipe_ingredients_update" ON recipe_ingredients;
DROP POLICY IF EXISTS "recipe_ingredients_delete" ON recipe_ingredients;

CREATE POLICY "recipe_ingredients_select" ON recipe_ingredients FOR SELECT USING (true);
CREATE POLICY "recipe_ingredients_insert" ON recipe_ingredients FOR INSERT WITH CHECK (true);
CREATE POLICY "recipe_ingredients_update" ON recipe_ingredients FOR UPDATE USING (true);
CREATE POLICY "recipe_ingredients_delete" ON recipe_ingredients FOR DELETE USING (true);

-- RLS Policies for production_logs
DROP POLICY IF EXISTS "production_logs_select" ON production_logs;
DROP POLICY IF EXISTS "production_logs_insert" ON production_logs;

CREATE POLICY "production_logs_select" ON production_logs FOR SELECT USING (true);
CREATE POLICY "production_logs_insert" ON production_logs FOR INSERT WITH CHECK (true);
