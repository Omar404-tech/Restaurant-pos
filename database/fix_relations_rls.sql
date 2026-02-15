-- =====================================================
-- Fix Login Issues: Public Access for Relations
-- =====================================================

-- 1. Enable RLS on branches and roles (if not already)
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

-- 2. Allow public read access to branches
DROP POLICY IF EXISTS "public_read_branches" ON branches;
CREATE POLICY "public_read_branches" ON branches
FOR SELECT
TO anon, authenticated
USING (true);

-- 3. Allow public read access to roles
DROP POLICY IF EXISTS "public_read_roles" ON roles;
CREATE POLICY "public_read_roles" ON roles
FOR SELECT
TO anon, authenticated
USING (true);

-- 4. Verify Policies
SELECT * FROM pg_policies WHERE tablename IN ('branches', 'roles');
