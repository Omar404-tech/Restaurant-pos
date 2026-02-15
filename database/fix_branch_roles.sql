-- =====================================================
-- FIX ROLES: Demote from Admin to Branch Supervisor
-- =====================================================

-- 1. Get the correct role ID for 'branch_supervisor'
-- Based on previous check, the name is 'branch_supervisor'
DO $$ 
DECLARE 
    v_supervisor_role_id UUID;
BEGIN
    SELECT id INTO v_supervisor_role_id FROM roles WHERE name = 'branch_supervisor' LIMIT 1;

    -- 2. Update Branch 3 and 4 users
    UPDATE users 
    SET role_id = v_supervisor_role_id 
    WHERE email IN ('branch3@restaurant.com', 'branch4@restaurant.com');
END $$;

-- 3. Verification Result
SELECT 
    u.email, 
    u.username,
    b.code as branch_code, 
    r.name as role_name,
    r.name_ar as role_name_ar
FROM users u
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN roles r ON u.role_id = r.id
WHERE u.email IN ('branch3@restaurant.com', 'branch4@restaurant.com');
