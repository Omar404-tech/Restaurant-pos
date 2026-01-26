-- ============================================
-- إضافة كاشير إضافي للفرع 1
-- Cashier 1C - أحمد محمود
-- ============================================

-- طريقة 1: استخدام Supabase Dashboard
-- =====================================
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى Authentication > Users
-- 3. اضغط "Add User"
-- 4. املأ البيانات:
--    - Email: cashier1c@restaurant.com
--    - Password: 1234
--    - Auto Confirm User: Yes
-- 5. بعد إنشاء المستخدم، اضغط عليه وأضف User Metadata:
--    {
--      "full_name": "أحمد محمود",
--      "full_name_ar": "أحمد محمود",
--      "role": "cashier",
--      "branch_id": "393fdf52-1982-481b-a254-11ba0edc1d8b",
--      "employee_code": "CASH1C"
--    }

-- ============================================
-- طريقة 2: استخدام SQL (للمطورين فقط)
-- ============================================
-- ملاحظة: هذا يتطلب صلاحيات admin في Supabase
-- يفضل استخدام Supabase Dashboard أو Admin API

-- التحقق من الفرع 1
SELECT id, code, name, name_ar 
FROM public.branches 
WHERE code = 'BR001';
-- Expected ID: 393fdf52-1982-481b-a254-11ba0edc1d8b

-- ============================================
-- طريقة 3: استخدام JavaScript/TypeScript
-- ============================================
/*
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.VITE_SUPABASE_URL
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY // Service role key required!

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

// Create the new cashier user
const { data, error } = await supabase.auth.admin.createUser({
  email: 'cashier1c@restaurant.com',
  password: '1234',
  email_confirm: true,
  user_metadata: {
    full_name: 'أحمد محمود',
    full_name_ar: 'أحمد محمود',
    role: 'cashier',
    branch_id: '393fdf52-1982-481b-a254-11ba0edc1d8b',
    employee_code: 'CASH1C'
  }
})

if (error) {
  console.error('Error creating user:', error)
} else {
  console.log('User created successfully:', data)
}
*/

-- ============================================
-- التحقق من المستخدمين الموجودين
-- ============================================
SELECT 
  id,
  email,
  raw_user_meta_data->>'full_name' as full_name,
  raw_user_meta_data->>'role' as role,
  raw_user_meta_data->>'branch_id' as branch_id,
  created_at
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'cashier'
  AND raw_user_meta_data->>'branch_id' = '393fdf52-1982-481b-a254-11ba0edc1d8b'
ORDER BY created_at;

-- ============================================
-- ملاحظات مهمة
-- ============================================
-- 1. كلمة المرور: 1234
-- 2. الإيميل: cashier1c@restaurant.com
-- 3. الدور: cashier
-- 4. الفرع: فرع 1 (BR001)
-- 5. الاسم: أحمد محمود
-- 6. الكود: CASH1C
