-- Fix Arabic encoding in database
-- Run this in Supabase SQL Editor

-- Fix suppliers table
UPDATE suppliers SET name_ar = 'المزارع الخضراء' WHERE code = 'SUP002';
UPDATE suppliers SET name_ar = 'موزع المشروبات' WHERE code = 'SUP004';
UPDATE suppliers SET name_ar = 'شركة اللحوم الطازجة' WHERE code = 'SUP001';
UPDATE suppliers SET name_ar = 'منتجات الألبان' WHERE code = 'SUP003';

-- Fix users table
UPDATE users SET full_name_ar = 'مدير النظام' WHERE email = 'admin@restaurant.com';
UPDATE users SET full_name_ar = 'أحمد محمد' WHERE email = 'warehouse@restaurant.com';
UPDATE users SET full_name_ar = 'محمد علي' WHERE email = 'branch1@restaurant.com';
UPDATE users SET full_name_ar = 'سارة أحمد' WHERE email = 'cashier1@restaurant.com';
UPDATE users SET full_name_ar = 'حسن إبراهيم' WHERE email = 'chef1@restaurant.com';

-- Fix menu_items table
UPDATE menu_items SET name_ar = 'دجاج مشوي' WHERE name_ar LIKE '%Ø¯Ø¬Ø§Ø¬%' OR name_ar LIKE '%دجاج%';
UPDATE menu_items SET name_ar = 'بيبسي' WHERE name_ar LIKE '%Ø¨ÙŠØ¨Ø³ÙŠ%' OR name_ar LIKE '%بيبسي%';

-- Fix items table  
UPDATE items SET name_ar = 'دجاج طازج' WHERE code = 'ITM001';
UPDATE items SET name_ar = 'لحم بقري' WHERE code = 'ITM002';
UPDATE items SET name_ar = 'أرز بسمتي' WHERE code = 'ITM003';
UPDATE items SET name_ar = 'زيت طبخ' WHERE code = 'ITM004';
UPDATE items SET name_ar = 'بصل' WHERE code = 'ITM005';
UPDATE items SET name_ar = 'طماطم' WHERE code = 'ITM006';
UPDATE items SET name_ar = 'ثوم' WHERE code = 'ITM007';
UPDATE items SET name_ar = 'ملح' WHERE code = 'ITM008';
UPDATE items SET name_ar = 'فلفل أسود' WHERE code = 'ITM009';
UPDATE items SET name_ar = 'كمون' WHERE code = 'ITM010';

-- Fix branches table
UPDATE branches SET name_ar = 'المخزن الرئيسي' WHERE code = 'WH001' OR is_main_warehouse = true;
UPDATE branches SET name_ar = 'فرع 1' WHERE code = 'BR001';
UPDATE branches SET name_ar = 'فرع 2' WHERE code = 'BR002';

-- Fix roles table
UPDATE roles SET name_ar = 'مدير النظام' WHERE name = 'admin';
UPDATE roles SET name_ar = 'مدير المخزن' WHERE name = 'warehouse_manager';
UPDATE roles SET name_ar = 'مشرف الفرع' WHERE name = 'branch_supervisor';
UPDATE roles SET name_ar = 'كاشير' WHERE name = 'cashier';
UPDATE roles SET name_ar = 'شيف' WHERE name = 'chef';
UPDATE roles SET name_ar = 'مدير المشتريات' WHERE name = 'purchase_manager';

-- Fix categories table
UPDATE categories SET name_ar = 'لحوم' WHERE name = 'Meat' OR name_ar LIKE '%Ù„Ø­%';
UPDATE categories SET name_ar = 'خضروات' WHERE name = 'Vegetables' OR name_ar LIKE '%Ø®Ø¶%';
UPDATE categories SET name_ar = 'توابل' WHERE name = 'Spices' OR name_ar LIKE '%ØªÙˆØ§%';
UPDATE categories SET name_ar = 'زيوت' WHERE name = 'Oils' OR name_ar LIKE '%Ø²ÙŠ%';
UPDATE categories SET name_ar = 'حبوب' WHERE name = 'Grains' OR name_ar LIKE '%Ø­Ø¨%';
UPDATE categories SET name_ar = 'مشروبات' WHERE name = 'Beverages' OR name_ar LIKE '%Ù…Ø´Ø±%';

-- Fix damage_reasons table
UPDATE damage_reasons SET name_ar = 'منتهي الصلاحية' WHERE name = 'Expired';
UPDATE damage_reasons SET name_ar = 'تالف' WHERE name = 'Damaged';
UPDATE damage_reasons SET name_ar = 'مكسور' WHERE name = 'Broken';
UPDATE damage_reasons SET name_ar = 'فاسد' WHERE name = 'Spoiled';
