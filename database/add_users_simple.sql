-- Simple version to test
-- Branch 3 User
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
    status
) VALUES (
    'branch3',
    'branch3@restaurant.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5',
    'Branch 3 Supervisor',
    'مشرف منفذ البيع الثالث',
    '01000000013',
    'EMP-BR03-001',
    (SELECT id FROM roles WHERE name = 'مشرف منفذ'),
    (SELECT id FROM branches WHERE code = 'BR03'),
    'active'
);

-- Branch 4 User
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
    status
) VALUES (
    'branch4',
    'branch4@restaurant.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMye1J8YQ9CpO7LZhiLZ6pJQ5z5z5z5z5z5',
    'Branch 4 Supervisor',
    'مشرف منفذ البيع الرابع',
    '01000000015',
    'EMP-BR04-001',
    (SELECT id FROM roles WHERE name = 'مشرف منفذ'),
    (SELECT id FROM branches WHERE code = 'BR04'),
    'active'
);

-- Verify
SELECT * FROM users WHERE username IN ('branch3', 'branch4');
