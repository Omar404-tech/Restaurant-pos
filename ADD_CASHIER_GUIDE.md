# دليل إضافة كاشير إضافي للفرع 1
# Guide to Add Additional Cashier to Branch 1

## 📋 معلومات الكاشير الجديد / New Cashier Information

- **الاسم / Name:** أحمد محمود
- **الإيميل / Email:** cashier1c@restaurant.com
- **كلمة المرور / Password:** 1234
- **الدور / Role:** كاشير / Cashier
- **الفرع / Branch:** فرع 1 / Branch 1 (BR001)
- **كود الموظف / Employee Code:** CASH1C

---

## 🎯 الطرق المتاحة / Available Methods

### الطريقة 1: استخدام Supabase Dashboard (الأسهل) ⭐

1. افتح [Supabase Dashboard](https://app.supabase.com)
2. اختر مشروعك
3. اذهب إلى **Authentication** > **Users**
4. اضغط على **Add User** أو **Invite User**
5. املأ البيانات:
   ```
   Email: cashier1c@restaurant.com
   Password: 1234
   Auto Confirm User: ✅ Yes
   ```
6. بعد إنشاء المستخدم، اضغط عليه
7. اذهب إلى **User Metadata** واضغط **Edit**
8. أضف البيانات التالية:
   ```json
   {
     "full_name": "أحمد محمود",
     "full_name_ar": "أحمد محمود",
     "role": "cashier",
     "branch_id": "393fdf52-1982-481b-a254-11ba0edc1d8b",
     "employee_code": "CASH1C"
   }
   ```
9. احفظ التغييرات

---

### الطريقة 2: استخدام JavaScript Script

#### المتطلبات:
```bash
npm install @supabase/supabase-js dotenv
```

#### الخطوات:

1. **أضف Service Role Key في ملف `.env`:**
   ```env
   VITE_SUPABASE_URL=your_supabase_url
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```

2. **شغل السكريبت:**
   ```bash
   node add_cashier.js
   ```

3. **تحقق من النتيجة:**
   - السكريبت هيطبع تفاصيل المستخدم الجديد
   - هيعرض قائمة بكل الكاشيرات في الفرع 1

---

### الطريقة 3: استخدام Supabase SQL Editor

1. افتح **SQL Editor** في Supabase Dashboard
2. شغل الكود التالي للتحقق من الفرع:
   ```sql
   SELECT id, code, name, name_ar 
   FROM public.branches 
   WHERE code = 'BR001';
   ```
3. استخدم Supabase Dashboard لإضافة المستخدم (الطريقة 1)

---

## ✅ التحقق من نجاح العملية / Verification

### في Supabase Dashboard:
1. اذهب إلى **Authentication** > **Users**
2. ابحث عن `cashier1c@restaurant.com`
3. تأكد من وجود User Metadata الصحيح

### باستخدام SQL:
```sql
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
```

### في التطبيق:
1. افتح التطبيق: http://localhost:5173/
2. سجل دخول بالبيانات:
   - Email: `cashier1c@restaurant.com`
   - Password: `1234`
3. تأكد من الوصول لصفحة POS للفرع 1

---

## 📊 ملخص الكاشيرات في الفرع 1 / Branch 1 Cashiers Summary

بعد إضافة الكاشير الجديد، الفرع 1 سيكون عنده:

| # | الإيميل | الاسم | الكود |
|---|---------|-------|-------|
| 1 | cashier1@restaurant.com | Cashier 1 | CASH1 |
| 2 | cashier1b@restaurant.com | ليلى حسن | CASH1B |
| 3 | cashier1c@restaurant.com | أحمد محمود | CASH1C ⭐ NEW |

---

## 🔧 استكشاف الأخطاء / Troubleshooting

### المشكلة: "Email already exists"
- **الحل:** المستخدم موجود بالفعل. استخدم إيميل مختلف أو احذف المستخدم القديم.

### المشكلة: "Invalid service role key"
- **الحل:** تأكد من استخدام Service Role Key وليس Anon Key في `.env`

### المشكلة: "Branch ID not found"
- **الحل:** تأكد من Branch ID الصحيح باستخدام:
  ```sql
  SELECT id FROM branches WHERE code = 'BR001';
  ```

---

## 📝 ملاحظات مهمة / Important Notes

1. ✅ كلمة المرور الافتراضية: `1234`
2. ✅ يجب تغيير كلمة المرور عند أول تسجيل دخول (في الإنتاج)
3. ✅ تأكد من صلاحيات الكاشير في النظام
4. ✅ الكاشير يمكنه الوصول فقط لصفحة POS في فرعه
5. ✅ لا يمكن للكاشير الوصول لصفحات الإدارة

---

## 🎉 تم بنجاح!

الآن الفرع 1 عنده **3 كاشيرات** جاهزين للعمل! 🎊
