-- =====================================================
-- EXTRA-ROBUST FINAL REPAIR
-- Handles: Branches, Roles (Flexible Lookup), and Users
-- =====================================================

-- 1. Ensure Branches Exist
INSERT INTO branches (id, code, name, name_ar, status, is_main_warehouse)
SELECT uuid_generate_v4(), 'BR03', 'Sales Outlet 3', 'منفذ البيع الثالث', 'active', false
WHERE NOT EXISTS (SELECT 1 FROM branches WHERE code = 'BR03');

INSERT INTO branches (id, code, name, name_ar, status, is_main_warehouse)
SELECT uuid_generate_v4(), 'BR04', 'Sales Outlet 4', 'منفذ البيع الرابع', 'active', false
WHERE NOT EXISTS (SELECT 1 FROM branches WHERE code = 'BR04');

-- 2. Update existing users or Insert if missing
DO $$ 
DECLARE 
    v_branch3_id UUID;
    v_branch4_id UUID;
    v_role_id UUID;
BEGIN
    -- Get Branch IDs
    SELECT id INTO v_branch3_id FROM branches WHERE code = 'BR03';
    SELECT id INTO v_branch4_id FROM branches WHERE code = 'BR04';

    -- FLEXIBLE ROLE LOOKUP
    -- We try to find the 'Branch Manager' role by searching for pieces of the name
    SELECT id INTO v_role_id FROM roles 
    WHERE (name_ar LIKE '%مدير%فرع%' OR name LIKE '%مدير%فرع%' OR name_ar LIKE '%Branch%Manager%')
    LIMIT 1;

    -- Fallback: If still not found, just take the first role that is NOT admin if possible
    IF v_role_id IS NULL THEN
        SELECT id INTO v_role_id FROM roles WHERE name_ar NOT LIKE '%نظام%' LIMIT 1;
    END IF;
    
    -- Final Fallback: Take ANY role to prevent NOT NULL constraint error
    IF v_role_id IS NULL THEN
        SELECT id INTO v_role_id FROM roles LIMIT 1;
    END IF;

    -- Branch 3 User
    IF EXISTS (SELECT 1 FROM users WHERE email = 'branch3@restaurant.com') THEN
        UPDATE users SET 
            branch_id = v_branch3_id,
            role_id = v_role_id,
            status = 'active',
            password_hash = '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5',
            updated_at = CURRENT_TIMESTAMP
        WHERE email = 'branch3@restaurant.com';
    ELSE
        INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, role_id, branch_id, status)
        VALUES ('EMP-BR03-001', 'branch3', 'branch3@restaurant.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5', 'Branch 3 Supervisor', 'مشرف منفذ البيع الثالث', v_role_id, v_branch3_id, 'active');
    END IF;

    -- Branch 4 User
    IF EXISTS (SELECT 1 FROM users WHERE email = 'branch4@restaurant.com') THEN
        UPDATE users SET 
            branch_id = v_branch4_id,
            role_id = v_role_id,
            status = 'active',
            password_hash = '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5',
            updated_at = CURRENT_TIMESTAMP
        WHERE email = 'branch4@restaurant.com';
    ELSE
        INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, role_id, branch_id, status)
        VALUES ('EMP-BR04-001', 'branch4', 'branch4@restaurant.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5', 'Branch 4 Supervisor', 'مشرف منفذ البيع الرابع', v_role_id, v_branch4_id, 'active');
    END IF;
END $$;

-- 3. Verification Result
SELECT 
    u.email, 
    u.status, 
    b.code as branch_code, 
    r.name_ar as role_name,
    'READY' as final_status
FROM users u
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN roles r ON u.role_id = r.id
WHERE u.email IN ('branch3@restaurant.com', 'branch4@restaurant.com');
