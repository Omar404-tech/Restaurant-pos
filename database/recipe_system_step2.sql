-- Step 2: Add is_recipe column to items table
ALTER TABLE items ADD COLUMN IF NOT EXISTS is_recipe BOOLEAN DEFAULT false;
