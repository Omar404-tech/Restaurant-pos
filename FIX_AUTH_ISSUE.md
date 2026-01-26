# 🔧 إصلاح مشكلة "فشل في إضافة المنتج"

## المشكلة
النظام يستخدم RLS (Row Level Security) policies التي تعتمد على `auth.uid()` من Supabase Auth، لكن تسجيل الدخول الحالي لا يستخدم Supabase Auth، مما يجعل `auth.uid()` يعيد NULL.

## الحل السريع (مؤقت)

### الخيار 1: تعطيل RLS مؤقتاً
قم بتنفيذ هذا الأمر في Supabase SQL Editor:

```sql
-- تعطيل RLS مؤقتاً على جدول branch_pos_items
ALTER TABLE branch_pos_items DISABLE ROW LEVEL SECURITY;
```

بعد ذلك، جرب إضافة المنتج مرة أخرى. يجب أن يعمل الآن.

⚠️ **تحذير**: هذا الحل مؤقت وغير آمن للإنتاج!

---

## الحل الدائم (موصى به)

### الخطوة 1: إنشاء مستخدمي Supabase Auth

يجب إنشاء حسابات Supabase Auth لجميع المستخدمين. هناك طريقتان:

#### الطريقة الأولى: من خلال Supabase Dashboard

1. اذهب إلى Supabase Dashboard
2. اختر مشروعك
3. اذهب إلى **Authentication** → **Users**
4. اضغط **Add user** → **Create new user**
5. أنشئ المستخدمين التاليين:

| Email | Password | User ID (مهم!) |
|-------|----------|----------------|
| admin@restaurant.com | 1234 | نفس الـ ID من جدول users |
| warehouse@restaurant.com | 1234 | نفس الـ ID من جدول users |
| cashier1@restaurant.com | 1234 | نفس الـ ID من جدول users |
| cashier1b@restaurant.com | 1234 | نفس الـ ID من جدول users |
| cashier2@restaurant.com | 1234 | نفس الـ ID من جدول users |
| branch1@restaurant.com | 1234 | نفس الـ ID من جدول users |
| branch2@restaurant.com | 1234 | نفس الـ ID من جدول users |
| chef1@restaurant.com | 1234 | نفس الـ ID من جدول users |
| chef2@restaurant.com | 1234 | نفس الـ ID من جدول users |
| purchase@restaurant.com | 1234 | نفس الـ ID من جدول users |

**مهم جداً**: عند إنشاء كل مستخدم، استخدم نفس الـ UUID الموجود في جدول `users` لهذا المستخدم.

#### الطريقة الثانية: استخدام Supabase Admin API

إذا كان لديك Admin API Key، يمكنك تشغيل هذا السكريبت:

```javascript
// create-auth-users.js
const { createClient } = require('@supabase/supabase-js')

const supabaseUrl = 'YOUR_SUPABASE_URL'
const supabaseServiceKey = 'YOUR_SERVICE_ROLE_KEY' // من Project Settings → API

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

const users = [
  { email: 'admin@restaurant.com', password: '1234', id: 'GET_FROM_DATABASE' },
  { email: 'warehouse@restaurant.com', password: '1234', id: 'GET_FROM_DATABASE' },
  // ... أضف باقي المستخدمين
]

async function createAuthUsers() {
  for (const user of users) {
    const { data, error } = await supabase.auth.admin.createUser({
      email: user.email,
      password: user.password,
      email_confirm: true,
      user_metadata: { full_name: user.email.split('@')[0] }
    })
    
    if (error) {
      console.error(`Failed to create ${user.email}:`, error.message)
    } else {
      console.log(`✅ Created auth user: ${user.email}`)
      
      // Update the users table to match the auth ID
      const { error: updateError } = await supabase
        .from('users')
        .update({ id: data.user.id })
        .eq('email', user.email)
      
      if (updateError) {
        console.error(`Failed to update user ID for ${user.email}:`, updateError.message)
      }
    }
  }
}

createAuthUsers()
```

### الخطوة 2: تحديث AuthContext (تم بالفعل ✅)

تم تحديث ملف `AuthContext.tsx` ليستخدم Supabase Auth بدلاً من التحقق المخصص.

### الخطوة 3: إعادة تفعيل RLS

بعد إنشاء مستخدمي Auth، قم بتفعيل RLS مرة أخرى:

```sql
-- إعادة تفعيل RLS
ALTER TABLE branch_pos_items ENABLE ROW LEVEL SECURITY;
```

### الخطوة 4: اختبار النظام

1. قم بتسجيل الخروج من النظام
2. سجل الدخول مرة أخرى كـ admin@restaurant.com / 1234
3. اذهب إلى "إدارة نقاط البيع"
4. جرب إضافة منتج

يجب أن يعمل الآن! ✅

---

## التحقق من المشكلة

لمعرفة ما إذا كان المستخدم لديه حساب Auth أم لا:

```sql
SELECT 
    u.email,
    u.full_name_ar,
    r.name as role,
    CASE WHEN au.id IS NOT NULL THEN 'نعم ✅' ELSE 'لا ❌' END as has_auth_user
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
LEFT JOIN auth.users au ON au.id = u.id
WHERE u.status = 'active'
ORDER BY r.name, u.email;
```

---

## ملاحظات مهمة

1. **الأمان**: RLS مهم جداً للأمان. لا تعطله في الإنتاج.
2. **User IDs**: يجب أن يكون الـ ID في جدول `users` مطابقاً للـ ID في `auth.users`
3. **كلمة المرور**: جميع المستخدمين يستخدمون كلمة المرور `1234` للتطوير فقط
4. **Email Confirmation**: تأكد من تأكيد البريد الإلكتروني عند إنشاء المستخدمين

---

## إذا استمرت المشكلة

إذا استمرت المشكلة بعد تطبيق الحل، تحقق من:

1. هل تم تسجيل الدخول بنجاح؟
2. هل يظهر خطأ في Console المتصفح؟
3. هل الـ auth.uid() يعيد قيمة صحيحة؟

يمكنك التحقق من auth.uid() بتشغيل:

```sql
SELECT auth.uid();
```

إذا أعاد NULL، فالمشكلة في تسجيل الدخول.

---

## الدعم

إذا واجهت أي مشكلة، أرسل:
1. رسالة الخطأ من Console المتصفح
2. نتيجة استعلام التحقق أعلاه
3. لقطة شاشة من المشكلة
