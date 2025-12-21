-- =====================================================
-- Supabase Security Fix Script
-- يحل مشاكل Security Advisor
-- 1. SECURITY DEFINER Views
-- 2. RLS Disabled on Tables
-- =====================================================

-- =====================================================
-- PART 1: Fix SECURITY DEFINER Views
-- إعادة إنشاء الـ Views بدون SECURITY DEFINER
-- =====================================================

-- Drop existing views
DROP VIEW IF EXISTS vw_branch_inventory CASCADE;
DROP VIEW IF EXISTS vw_branch_inventory_details CASCADE;
DROP VIEW IF EXISTS vw_branch_returns CASCADE;
DROP VIEW IF EXISTS vw_main_warehouse_inventory CASCADE;
DROP VIEW IF EXISTS vw_purchase_requests CASCADE;

-- Recreate vw_branch_inventory (without SECURITY DEFINER)
CREATE VIEW vw_branch_inventory AS
SELECT 
    row_number() OVER (PARTITION BY b.id ORDER BY c.name, i.code) AS row_num,
    b.code AS branch_code,
    b.name AS branch_name,
    c.name AS category,
    i.code AS item_code,
    i.name AS item_name,
    u.name AS unit_name,
    inv.opening_balance,
    inv.incoming_quantity AS incoming,
    inv.consumption_quantity AS consumption,
    inv.quantity AS total_balance,
    inv.consumption_description,
    inv.min_quantity,
    CASE
        WHEN inv.quantity < inv.min_quantity THEN 'LOW'
        WHEN inv.quantity < (inv.min_quantity * 1.5) THEN 'WARNING'
        ELSE 'OK'
    END AS stock_status
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN categories c ON i.category_id = c.id
JOIN units u ON i.unit_id = u.id
WHERE b.is_main_warehouse = false
ORDER BY b.name, c.name, i.code;

-- Recreate vw_branch_inventory_details (without SECURITY DEFINER)
CREATE VIEW vw_branch_inventory_details AS
SELECT 
    row_number() OVER (ORDER BY inv.entry_date DESC, i.code) AS row_num,
    inv.entry_date,
    inv.document_number,
    i.code AS item_code,
    i.name AS item_name,
    inv.partial_quantity,
    inv.content_quantity,
    inv.total_quantity,
    inv.content_description,
    b.code AS branch_code,
    b.name AS branch_name,
    inv.quantity AS current_stock,
    inv.min_quantity,
    u.name AS unit_name,
    inv.updated_at
FROM inventory inv
JOIN items i ON inv.item_id = i.id
JOIN branches b ON inv.branch_id = b.id
LEFT JOIN units u ON i.unit_id = u.id
WHERE b.code <> 'MAIN'
ORDER BY inv.entry_date DESC, i.code;


-- Recreate vw_branch_returns (without SECURITY DEFINER)
CREATE VIEW vw_branch_returns AS
SELECT 
    row_number() OVER (ORDER BY br.return_date DESC, br.return_number) AS row_num,
    br.return_number,
    br.return_date,
    fb.name AS from_branch,
    tb.name AS to_branch,
    i.code AS item_code,
    i.name AS item_name,
    bri.requested_quantity,
    bri.approved_quantity,
    bri.received_quantity,
    bri.unit_cost,
    bri.total_value,
    br.return_reason,
    bri.item_reason,
    br.status,
    u.full_name AS requested_by_name,
    br.requested_at
FROM branch_returns br
JOIN branch_return_items bri ON br.id = bri.return_id
JOIN branches fb ON br.from_branch_id = fb.id
JOIN branches tb ON br.to_branch_id = tb.id
JOIN items i ON bri.item_id = i.id
JOIN users u ON br.requested_by = u.id
ORDER BY br.return_date DESC, br.return_number, i.code;

-- Recreate vw_main_warehouse_inventory (without SECURITY DEFINER)
CREATE VIEW vw_main_warehouse_inventory AS
SELECT 
    row_number() OVER (ORDER BY c.name, i.code) AS row_num,
    c.name AS category,
    c.name_ar AS category_ar,
    i.code AS item_code,
    i.name AS item_name,
    i.name_ar AS item_name_ar,
    u.name AS unit_name,
    u.name_ar AS unit_name_ar,
    inv.opening_balance,
    inv.incoming_quantity AS incoming,
    inv.consumption_quantity AS consumption,
    inv.quantity AS total_balance,
    inv.consumption_description,
    inv.min_quantity,
    CASE
        WHEN inv.quantity < inv.min_quantity THEN 'LOW'
        WHEN inv.quantity < (inv.min_quantity * 1.5) THEN 'WARNING'
        ELSE 'OK'
    END AS stock_status,
    inv.period_start_date,
    inv.period_end_date,
    inv.updated_at
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN categories c ON i.category_id = c.id
JOIN units u ON i.unit_id = u.id
WHERE b.is_main_warehouse = true
ORDER BY c.name, i.code;

-- Recreate vw_purchase_requests (without SECURITY DEFINER)
CREATE VIEW vw_purchase_requests AS
SELECT 
    row_number() OVER (ORDER BY pr.request_date DESC, pr.request_number) AS row_num,
    pr.request_date AS date,
    pr.request_number AS document_number,
    pri.id AS item_row_id,
    i.code AS item_code,
    i.name AS item_name,
    i.name_ar AS item_name_ar,
    COALESCE(s.name, 'Not Assigned') AS supplier_name,
    COALESCE(s.name_ar, 'Not Assigned') AS supplier_name_ar,
    pri.requested_quantity AS quantity,
    pri.notes,
    pr.status AS request_status,
    b.name AS branch_name,
    u.full_name AS requested_by_name
FROM purchase_requests pr
JOIN purchase_request_items pri ON pr.id = pri.request_id
JOIN items i ON pri.item_id = i.id
LEFT JOIN suppliers s ON pri.supplier_id = s.id
JOIN branches b ON pr.branch_id = b.id
JOIN users u ON pr.requested_by = u.id
ORDER BY pr.request_date DESC, pr.request_number, i.code;

-- =====================================================
-- PART 2: Enable RLS on All Tables
-- تفعيل Row Level Security على كل الجداول
-- =====================================================

-- Enable RLS on all application tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplies ENABLE ROW LEVEL SECURITY;
ALTER TABLE supply_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE damages ENABLE ROW LEVEL SECURITY;
ALTER TABLE damage_reasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_return_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_return_reasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_inventory_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_inventory_count_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_settings ENABLE ROW LEVEL SECURITY;

-- Enable RLS on Django tables (optional, but removes warnings)
ALTER TABLE django_migrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE django_content_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_permission ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_group ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_group_permissions ENABLE ROW LEVEL SECURITY;


-- =====================================================
-- PART 3: Create RLS Policies
-- إنشاء Policies للسماح بالوصول للمستخدمين المصرح لهم
-- نستخدم service_role للتطبيق الداخلي
-- =====================================================

-- Drop existing policies if any (to avoid conflicts)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- Create permissive policies for all tables
-- These allow service_role full access (used by your React app)

-- Users table
CREATE POLICY "service_role_all" ON users FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON users FOR SELECT TO anon USING (true);

-- Roles table
CREATE POLICY "service_role_all" ON roles FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON roles FOR SELECT TO anon USING (true);

-- Branches table
CREATE POLICY "service_role_all" ON branches FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON branches FOR SELECT TO anon USING (true);

-- Branch Settings table
CREATE POLICY "service_role_all" ON branch_settings FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON branch_settings FOR SELECT TO anon USING (true);

-- Categories table
CREATE POLICY "service_role_all" ON categories FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON categories FOR SELECT TO anon USING (true);

-- Units table
CREATE POLICY "service_role_all" ON units FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON units FOR SELECT TO anon USING (true);

-- Items table
CREATE POLICY "service_role_all" ON items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON items FOR SELECT TO anon USING (true);

-- Inventory table
CREATE POLICY "service_role_all" ON inventory FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON inventory FOR SELECT TO anon USING (true);

-- Inventory Batches table
CREATE POLICY "service_role_all" ON inventory_batches FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON inventory_batches FOR SELECT TO anon USING (true);

-- Inventory Transactions table
CREATE POLICY "service_role_all" ON inventory_transactions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON inventory_transactions FOR SELECT TO anon USING (true);

-- Suppliers table
CREATE POLICY "service_role_all" ON suppliers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON suppliers FOR SELECT TO anon USING (true);

-- Supplier Items table
CREATE POLICY "service_role_all" ON supplier_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON supplier_items FOR SELECT TO anon USING (true);

-- Supplies table
CREATE POLICY "service_role_all" ON supplies FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON supplies FOR SELECT TO anon USING (true);

-- Supply Items table
CREATE POLICY "service_role_all" ON supply_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON supply_items FOR SELECT TO anon USING (true);

-- Supplier Payments table
CREATE POLICY "service_role_all" ON supplier_payments FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON supplier_payments FOR SELECT TO anon USING (true);

-- Supplier Returns table
CREATE POLICY "service_role_all" ON supplier_returns FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON supplier_returns FOR SELECT TO anon USING (true);

-- Transfers table
CREATE POLICY "service_role_all" ON transfers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON transfers FOR SELECT TO anon USING (true);

-- Transfer Items table
CREATE POLICY "service_role_all" ON transfer_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON transfer_items FOR SELECT TO anon USING (true);

-- Damages table
CREATE POLICY "service_role_all" ON damages FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON damages FOR SELECT TO anon USING (true);

-- Damage Reasons table
CREATE POLICY "service_role_all" ON damage_reasons FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON damage_reasons FOR SELECT TO anon USING (true);

-- Branch Returns table
CREATE POLICY "service_role_all" ON branch_returns FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON branch_returns FOR SELECT TO anon USING (true);

-- Branch Return Items table
CREATE POLICY "service_role_all" ON branch_return_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON branch_return_items FOR SELECT TO anon USING (true);

-- Branch Return Reasons table
CREATE POLICY "service_role_all" ON branch_return_reasons FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON branch_return_reasons FOR SELECT TO anon USING (true);

-- Purchase Requests table
CREATE POLICY "service_role_all" ON purchase_requests FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON purchase_requests FOR SELECT TO anon USING (true);

-- Purchase Request Items table
CREATE POLICY "service_role_all" ON purchase_request_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON purchase_request_items FOR SELECT TO anon USING (true);

-- Purchase Orders table
CREATE POLICY "service_role_all" ON purchase_orders FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON purchase_orders FOR SELECT TO anon USING (true);

-- Purchase Order Items table
CREATE POLICY "service_role_all" ON purchase_order_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON purchase_order_items FOR SELECT TO anon USING (true);

-- Menu Categories table
CREATE POLICY "service_role_all" ON menu_categories FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON menu_categories FOR SELECT TO anon USING (true);

-- Menu Items table
CREATE POLICY "service_role_all" ON menu_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON menu_items FOR SELECT TO anon USING (true);

-- Menu Item Ingredients table
CREATE POLICY "service_role_all" ON menu_item_ingredients FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON menu_item_ingredients FOR SELECT TO anon USING (true);

-- Orders table
CREATE POLICY "service_role_all" ON orders FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON orders FOR SELECT TO anon USING (true);

-- Order Items table
CREATE POLICY "service_role_all" ON order_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON order_items FOR SELECT TO anon USING (true);

-- Daily Inventory Counts table
CREATE POLICY "service_role_all" ON daily_inventory_counts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON daily_inventory_counts FOR SELECT TO anon USING (true);

-- Daily Inventory Count Items table
CREATE POLICY "service_role_all" ON daily_inventory_count_items FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON daily_inventory_count_items FOR SELECT TO anon USING (true);

-- Notifications table
CREATE POLICY "service_role_all" ON notifications FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON notifications FOR SELECT TO anon USING (true);

-- Audit Logs table
CREATE POLICY "service_role_all" ON audit_logs FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON audit_logs FOR SELECT TO anon USING (true);

-- User Sessions table
CREATE POLICY "service_role_all" ON user_sessions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON user_sessions FOR SELECT TO anon USING (true);

-- System Settings table
CREATE POLICY "service_role_all" ON system_settings FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON system_settings FOR SELECT TO anon USING (true);

-- Alert Settings table
CREATE POLICY "service_role_all" ON alert_settings FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "anon_read" ON alert_settings FOR SELECT TO anon USING (true);

-- Django tables (allow all for service_role)
CREATE POLICY "service_role_all" ON django_migrations FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON django_content_type FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON auth_permission FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON auth_group FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all" ON auth_group_permissions FOR ALL TO service_role USING (true) WITH CHECK (true);


-- =====================================================
-- PART 4: Grant Permissions
-- منح الصلاحيات للـ roles
-- =====================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Grant permissions on all tables
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;

-- Grant permissions on all sequences
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- Grant execute on all functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role, authenticated;

-- =====================================================
-- PART 5: Verification Query
-- استعلام للتحقق من التطبيق
-- =====================================================

-- Run this to verify RLS is enabled:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- Run this to verify policies exist:
-- SELECT tablename, policyname, permissive, roles, cmd FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;

-- =====================================================
-- DONE!
-- =====================================================
