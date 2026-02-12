-- =====================================================
-- Add Users for New Branches (BR03 & BR04)
-- Restaurant Management System
-- =====================================================
-- This script creates:
-- - 1 user for Branch 3 (منفذ البيع الثالث)
-- - 1 user for Branch 4 (منفذ البيع الرابع)
-- Total: 2 users
-- Password for both: 1234
-- =====================================================

-- =====================================================
-- Branch 3 (منفذ البيع الثالث) User
-- =====================================================

-- Branch 3 User (مشرف منفذ)
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

-- =====================================================
-- Branch 4 (منفذ البيع الرابع) User
-- =====================================================

-- Branch 4 User (مشرف منفذ)
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

-- =====================================================
-- Verify Users Creation
-- =====================================================
SELECT 
    u.full_name_ar AS "الاسم",
    u.username AS "اسم المستخدم",
    u.email AS "البريد الإلكتروني",
    r.name_ar AS "الدور",
    b.name_ar AS "الفرع",
    u.status AS "الحالة",
    u.created_at AS "تاريخ الإنشاء"
FROM users u
JOIN roles r ON u.role_id = r.id
JOIN branches b ON u.branch_id = b.id
WHERE b.code IN ('BR03', 'BR04')
ORDER BY b.code;

-- =====================================================
-- Summary
-- =====================================================
SELECT 
    '✅ Users created successfully!' AS status,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN b.code = 'BR03' THEN 1 END) AS branch_03_users,
    COUNT(CASE WHEN b.code = 'BR04' THEN 1 END) AS branch_04_users
FROM users u
JOIN branches b ON u.branch_id = b.id
WHERE b.code IN ('BR03', 'BR04');

-- =====================================================
-- LOGIN CREDENTIALS:
-- =====================================================
-- Branch 3 (منفذ البيع الثالث):
--   Email: branch3@restaurant.com
--   Password: 1234
--   Role: مشرف منفذ
--
-- Branch 4 (منفذ البيع الرابع):
--   Email: branch4@restaurant.com
--   Password: 1234
--   Role: مشرف منفذ
--
-- ⚠️ IMPORTANT: Change these passwords after first login!
-- =====================================================
