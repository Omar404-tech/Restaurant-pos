-- Step 1: Add Recipe category
INSERT INTO categories (id, code, name, name_ar, description, is_active, sort_order)
VALUES (
  gen_random_uuid(),
  'CAT-RECIPE',
  'Recipes',
  'ريسبي',
  'المنتجات المصنعة من مكونات متعددة',
  true,
  100
)
ON CONFLICT (code) DO NOTHING;
