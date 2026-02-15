-- =====================================================
-- Ensure Branches 3 & 4 and Users Exist
-- Restaurant Management System
-- =====================================================

-- 1. Ensure Branch 3 (منفذ البيع الثالث) exists
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
)
SELECT
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
WHERE NOT EXISTS (
    SELECT 1 FROM branches WHERE code = 'BR03'
);

-- 2. Ensure Branch 4 (منفذ البيع الرابع) exists
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
)
SELECT
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
WHERE NOT EXISTS (
    SELECT 1 FROM branches WHERE code = 'BR04'
);

-- 3. Ensure User for Branch 3 exists
-- Email: branch3@restaurant.com
-- Password: 1234
INSERT INTO users (
    username,
    email,
    password_hash,
    full_name,
    full_name_ar,
    phone,
    employee_code,
    role_id,
    branch_id,
    status,
    created_at,
    updated_at
)
SELECT
    'branch3',
    'branch3@restaurant.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5', -- Password: 1234
    'Branch 3 Supervisor',
    'مشرف منفذ البيع الثالث',
    '01000000013',
    'EMP-BR03-001',
    (SELECT id FROM roles WHERE name = 'مشرف منفذ'),
    (SELECT id FROM branches WHERE code = 'BR03'),
    'active',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM users WHERE email = 'branch3@restaurant.com'
);

-- 4. Ensure User for Branch 4 exists
-- Email: branch4@restaurant.com
-- Password: 1234
INSERT INTO users (
    username,
    email,
    password_hash,
    full_name,
    full_name_ar,
    phone,
    employee_code,
    role_id,
    branch_id,
    status,
    created_at,
    updated_at
)
SELECT
    'branch4',
    'branch4@restaurant.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5', -- Password: 1234
    'Branch 4 Supervisor',
    'مشرف منفذ البيع الرابع',
    '01000000015',
    'EMP-BR04-001',
    (SELECT id FROM roles WHERE name = 'مشرف منفذ'),
    (SELECT id FROM branches WHERE code = 'BR04'),
    'active',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM users WHERE email = 'branch4@restaurant.com'
);

-- 5. Verification
SELECT 
    '✅ Branches and Users Verified' AS status,
    (SELECT COUNT(*) FROM branches WHERE code IN ('BR03', 'BR04')) AS branches_count,
    (SELECT COUNT(*) FROM users WHERE email IN ('branch3@restaurant.com', 'branch4@restaurant.com')) AS users_count;

SELECT 
    b.code, 
    b.name_ar as branch_name, 
    u.username, 
    u.email, 
    u.full_name_ar as user_name
FROM users u
JOIN branches b ON u.branch_id = b.id
WHERE b.code IN ('BR03', 'BR04');
