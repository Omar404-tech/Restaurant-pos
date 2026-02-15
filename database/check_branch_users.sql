-- Check Branch 1 and 2 users to see their roles and branch linking
SELECT 
    u.email, 
    u.username,
    b.code as branch_code, 
    r.id as role_id,
    r.name as role_name,
    r.name_ar as role_name_ar
FROM users u
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN roles r ON u.role_id = r.id
WHERE b.code IN ('BR001', 'BR002') OR u.email LIKE 'branch%@%';
