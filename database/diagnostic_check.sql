-- =====================================================
-- Diagnostic: List All Branches and Users
-- =====================================================

-- 1. List ALL Branches
SELECT '--- All Branches ---' as section;
SELECT id, code, name_ar, status FROM branches ORDER BY code;

-- 2. List ALL Users with their Roles and Branches
SELECT '--- All Users ---' as section;
SELECT 
    u.username, 
    u.email, 
    u.full_name_ar, 
    r.name_ar as role_name, 
    b.name_ar as branch_name,
    b.code as branch_code
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
LEFT JOIN branches b ON u.branch_id = b.id
ORDER BY b.code;

-- 3. Check for specific missing data for Branch 3 & 4
SELECT '--- Missing Links Check ---' as section;
SELECT 
    u.username,
    CASE WHEN u.role_id IS NULL THEN 'MISSING ROLE' ELSE 'OK' END as role_status,
    CASE WHEN u.branch_id IS NULL THEN 'MISSING BRANCH' ELSE 'OK' END as branch_status
FROM users u
WHERE u.email IN ('branch3@restaurant.com', 'branch4@restaurant.com');
