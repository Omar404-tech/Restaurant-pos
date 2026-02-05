-- =====================================================
-- Add Two New Branches (منفذ البيع الثالث والرابع)
-- Restaurant Management System
-- =====================================================

-- Insert Branch 3 (منفذ البيع الثالث)
INSERT INTO branches (
    id,
    code,
    name,
    name_ar,
    address,
    phone,
    status,
    is_main_warehouse,
    opening_time,
    closing_time,
    created_at,
    updated_at
) VALUES (
    uuid_generate_v4(),
    'BR03',
    'Sales Outlet 3',
    'منفذ البيع الثالث',
    'Address for Branch 3',
    '01000000003',
    'active',
    false,
    '09:00:00',
    '23:00:00',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- Insert Branch 4 (منفذ البيع الرابع)
INSERT INTO branches (
    id,
    code,
    name,
    name_ar,
    address,
    phone,
    status,
    is_main_warehouse,
    opening_time,
    closing_time,
    created_at,
    updated_at
) VALUES (
    uuid_generate_v4(),
    'BR04',
    'Sales Outlet 4',
    'منفذ البيع الرابع',
    'Address for Branch 4',
    '01000000004',
    'active',
    false,
    '09:00:00',
    '23:00:00',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- Verify the new branches
SELECT 
    code,
    name,
    name_ar,
    status,
    is_main_warehouse,
    created_at
FROM branches
ORDER BY code;

-- =====================================================
-- Optional: Create initial inventory records for new branches
-- (Run this after branches are created)
-- =====================================================

-- This will create inventory records for all items in the new branches
-- with zero quantity

-- For Branch 3
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT 
    (SELECT id FROM branches WHERE code = 'BR03'),
    id,
    0,
    min_stock_level
FROM items
WHERE status = 'active'
ON CONFLICT (branch_id, item_id) DO NOTHING;

-- For Branch 4
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT 
    (SELECT id FROM branches WHERE code = 'BR04'),
    id,
    0,
    min_stock_level
FROM items
WHERE status = 'active'
ON CONFLICT (branch_id, item_id) DO NOTHING;

-- Verify inventory creation
SELECT 
    b.code AS branch_code,
    b.name_ar AS branch_name,
    COUNT(i.id) AS total_items
FROM branches b
LEFT JOIN inventory i ON b.id = i.branch_id
WHERE b.code IN ('BR03', 'BR04')
GROUP BY b.code, b.name_ar
ORDER BY b.code;

-- =====================================================
-- Success Message
-- =====================================================
SELECT 
    '✅ Successfully added 2 new branches!' AS status,
    COUNT(*) AS total_branches
FROM branches
WHERE is_main_warehouse = false;
