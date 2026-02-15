-- =====================================================
-- Repair User-Branch Links and Roles for Branch 3 & 4
-- =====================================================

-- 1. Ensure Branches Exist (Idempotent)
INSERT INTO branches (id, code, name, name_ar, address, phone, status, is_main_warehouse, opening_time, closing_time)
SELECT uuid_generate_v4(), 'BR03', 'Sales Outlet 3', 'منفذ البيع الثالث', 'Address for Branch 3', '01000000003', 'active', false, '09:00:00', '23:00:00'
WHERE NOT EXISTS (SELECT 1 FROM branches WHERE code = 'BR03');

INSERT INTO branches (id, code, name, name_ar, address, phone, status, is_main_warehouse, opening_time, closing_time)
SELECT uuid_generate_v4(), 'BR04', 'Sales Outlet 4', 'منفذ البيع الرابع', 'Address for Branch 4', '01000000004', 'active', false, '09:00:00', '23:00:00'
WHERE NOT EXISTS (SELECT 1 FROM branches WHERE code = 'BR04');

-- 2. UPDATE Branch 3 User Link and Role
UPDATE users
SET 
    branch_id = (SELECT id FROM branches WHERE code = 'BR03'),
    role_id = (SELECT id FROM roles WHERE code = 'BRANCH_MANAGER'), -- Using 'مدير فرع'
    status = 'active',
    updated_at = CURRENT_TIMESTAMP
WHERE email = 'branch3@restaurant.com';

-- 3. UPDATE Branch 4 User Link and Role
UPDATE users
SET 
    branch_id = (SELECT id FROM branches WHERE code = 'BR04'),
    role_id = (SELECT id FROM roles WHERE code = 'BRANCH_MANAGER'), -- Using 'مدير فرع'
    status = 'active',
    updated_at = CURRENT_TIMESTAMP
WHERE email = 'branch4@restaurant.com';

-- 4. Verify Fix
SELECT 
    u.username, 
    u.email, 
    b.name_ar as branch_name, 
    r.name_ar as role_name,
    CASE WHEN u.branch_id IS NOT NULL AND u.role_id IS NOT NULL THEN 'FIXED' ELSE 'STILL BROKEN' END as status
FROM users u
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN roles r ON u.role_id = r.id
WHERE u.email IN ('branch3@restaurant.com', 'branch4@restaurant.com');
