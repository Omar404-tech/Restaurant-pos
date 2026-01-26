# تحديث صلاحيات استهلاك الطباخ ومشرفي الفروع

## التغييرات المطبقة

### 1. تحديث Sidebar (القائمة الجانبية)
**الملف:** `restaurant-react/src/components/layout/Sidebar.tsx`

تم تعديل صلاحيات القائمة الجانبية:

#### استهلاك الطباخ
- **قبل:** `['admin', 'warehouse_manager', 'branch_supervisor']`
- **بعد:** `['admin', 'warehouse_manager']`
- **النتيجة:** يظهر فقط للأدمن ومشرف الفرع الرئيسي

#### المخزون
- **قبل:** `['admin', 'warehouse_manager', 'branch_supervisor']`
- **بعد:** `['admin', 'warehouse_manager']`
- **النتيجة:** محجوب عن مشرفي الفروع

#### الريسبيات
- **قبل:** `['admin', 'warehouse_manager', 'branch_supervisor']`
- **بعد:** `['admin', 'warehouse_manager']`
- **النتيجة:** محجوب عن مشرفي الفروع

#### التحويلات والمرتجعات والتالف
- **الصلاحيات:** `['admin', 'warehouse_manager', 'branch_supervisor']`
- **النتيجة:** تظهر للأدمن ومشرف الفرع الرئيسي ومشرفين الفروع (1 و 2)

### 2. حماية صفحة استهلاك الطباخ
**الملف:** `restaurant-react/src/pages/inventory/ChefConsumption.tsx`

تم إضافة:
```typescript
import { Navigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'

// في بداية الكومبوننت
const { user } = useAuth()
const userRole = typeof user?.role === 'object' && user?.role !== null 
  ? (user.role as { name: string }).name 
  : user?.role

// حماية الصفحة
if (userRole && !['admin', 'warehouse_manager'].includes(userRole)) {
  return <Navigate to="/dashboard" replace />
}
```

### 3. حماية صفحة إضافة استهلاك الطباخ
**الملف:** `restaurant-react/src/pages/inventory/ChefConsumptionForm.tsx`

تم إضافة نفس الحماية لمنع الوصول المباشر من URL

## الصلاحيات النهائية

### مشرف الفرع الرئيسي (warehouse_manager)
✅ الفروع
✅ الموردين
✅ المخزون
✅ الريسبيات
✅ التحويلات
✅ المرتجعات
✅ التالف
✅ استهلاك الطباخ
✅ التقارير
✅ طلبات الشراء

### مشرف الفرع 1 و 2 (branch_supervisor) - branch1@restaurant.com / branch2@restaurant.com
✅ التحويلات (فرعه فقط)
✅ المرتجعات (فرعه فقط)
✅ التالف (فرعه فقط)
❌ لوحة التحكم
❌ الفروع
❌ الموردين
❌ المخزون
❌ الريسبيات
❌ استهلاك الطباخ
❌ نقطة البيع
❌ المطبخ
❌ التقارير
❌ طلبات الشراء
❌ المستخدمين
❌ الإعدادات

### الأدمن (admin)
✅ الوصول لكل الصفحات

## ملاحظات
- الحماية مطبقة على مستويين:
  1. القائمة الجانبية (UI)
  2. الصفحات نفسها (Route Protection)
- لو حد حاول يدخل من URL مباشرة، هيتم تحويله للـ Dashboard
- التغييرات متوافقة مع نظام الصلاحيات الموجود
- مشرفي الفروع يشوفوا فقط 3 صفحات: التحويلات، المرتجعات، والتالف
- كل مشرف فرع يشوف بيانات فرعه فقط
