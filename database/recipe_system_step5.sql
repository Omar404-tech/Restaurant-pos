-- Step 5: Create indexes
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient ON recipe_ingredients(ingredient_item_id);
CREATE INDEX IF NOT EXISTS idx_production_logs_recipe ON production_logs(recipe_item_id);
CREATE INDEX IF NOT EXISTS idx_production_logs_branch ON production_logs(branch_id);
CREATE INDEX IF NOT EXISTS idx_production_logs_date ON production_logs(produced_at);
CREATE INDEX IF NOT EXISTS idx_items_is_recipe ON items(is_recipe) WHERE is_recipe = true;
