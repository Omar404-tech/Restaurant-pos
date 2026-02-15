-- =====================================================
-- FINAL GUARANTEED REPAIR (FIXED)
-- This script handles everything: Branches, Roles, and Users
-- Fixed to use 'name' column instead of 'code' for Roles
-- =====================================================

-- 1. Ensure Branches Exist
INSERT INTO branches (id, code, name, name_ar, status, is_main_warehouse)
SELECT uuid_generate_v4(), 'BR03', 'Sales Outlet 3', 'منفذ البيع الثالث', 'active', false
WHERE NOT EXISTS (SELECT 1 FROM branches WHERE code = 'BR03');

INSERT INTO branches (id, code, name, name_ar, status, is_main_warehouse)
SELECT uuid_generate_v4(), 'BR04', 'Sales Outlet 4', 'منفذ البيع الرابع', 'active', false
WHERE NOT EXISTS (SELECT 1 FROM branches WHERE code = 'BR04');

-- 2. Update existing users or Insert if missing
-- Branch 3 User
DO $$ 
DECLARE 
    v_branch_id UUID;
    v_role_id UUID;
BEGIN
    SELECT id INTO v_branch_id FROM branches WHERE code = 'BR03';
    -- Match role by name since 'code' column is missing
    SELECT id INTO v_role_id FROM roles WHERE name = 'مدير فرع'; 

    IF EXISTS (SELECT 1 FROM users WHERE email = 'branch3@restaurant.com') THEN
        UPDATE users SET 
            branch_id = v_branch_id,
            role_id = v_role_id,
            status = 'active',
            password_hash = '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5',
            updated_at = CURRENT_TIMESTAMP
        WHERE email = 'branch3@restaurant.com';
    ELSE
        INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, role_id, branch_id, status)
        VALUES ('EMP-BR03-001', 'branch3', 'branch3@restaurant.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5', 'Branch 3 Supervisor', 'مشرف منفذ البيع الثالث', v_role_id, v_branch_id, 'active');
    END IF;
END $$;

-- Branch 4 User
DO $$ 
DECLARE 
    v_branch_id UUID;
    v_role_id UUID;
BEGIN
    SELECT id INTO v_branch_id FROM branches WHERE code = 'BR04';
    -- Match role by name since 'code' column is missing
    SELECT id INTO v_role_id FROM roles WHERE name = 'مدير فرع'; 

    IF EXISTS (SELECT 1 FROM users WHERE email = 'branch4@restaurant.com') THEN
        UPDATE users SET 
            branch_id = v_branch_id,
            role_id = v_role_id,
            status = 'active',
            password_hash = '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5',
            updated_at = CURRENT_TIMESTAMP
        WHERE email = 'branch4@restaurant.com';
    ELSE
        INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, role_id, branch_id, status)
        VALUES ('EMP-BR04-001', 'branch4', 'branch4@restaurant.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5', 'Branch 4 Supervisor', 'مشرف منفذ البيع الرابع', v_role_id, v_branch_id, 'active');
    END IF;
END $$;

-- 3. Verification Result
SELECT 
    u.email, 
    u.status, 
    b.code as branch_code, 
    r.name as role_name,
    'READY' as final_status
FROM users u
JOIN branches b ON u.branch_id = b.id
JOIN roles r ON u.role_id = r.id
WHERE u.email IN ('branch3@restaurant.com', 'branch4@restaurant.com');
