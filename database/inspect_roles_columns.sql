-- Inspect columns of the roles table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'roles' 
AND table_schema = 'public';
