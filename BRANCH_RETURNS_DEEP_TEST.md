# تقرير Deep Test - مرتجعات الفروع

## المشكلة المُبلغ عنها
مدير الفرع بيعمل مرتجع ومش بيظهر

## التحليل والفحص

### 1. فحص قاعدة البيانات ✅
- جدول `branch_returns` موجود وفيه بيانات (6 سجلات)
- جدول `branch_return_items` موجود وفيه بيانات (8 سجلات)
- الـ Foreign Keys صحيحة
- الـ RLS غير مفعل على الجداول

### 2. فحص الـ Constraints
- `return_reason` مطلوب (NOT NULL) ← **مشكلة محتملة**
- `requested_by` مطلوب (NOT NULL) ← **مشكلة محتملة**
- `from_branch_id` و `to_branch_id` مطلوبين

### 3. المشاكل المكتشفة والإصلاحات

#### المشكلة 1: عدم التحقق من `return_reason`
**الوصف:** الحقل `return_reason` مطلوب في قاعدة البيانات لكن الـ form كان يسمح بإرساله فارغاً
**الإصلاح:** 
- إضافة validation للتأكد من إدخال سبب الإرجاع
- إضافة علامة `*` للحقل المطلوب
- إضافة `required` attribute

#### المشكلة 2: عدم التحقق من `user.id`
**الوصف:** الحقل `requested_by` مطلوب لكن لم يكن هناك تحقق من وجود المستخدم
**الإصلاح:** إضافة validation للتأكد من تسجيل الدخول

#### المشكلة 3: عدم تعيين الفرع تلقائياً لمدير الفرع
**الوصف:** مدير الفرع كان يحتاج لاختيار فرعه يدوياً
**الإصلاح:** 
- تعيين الفرع تلقائياً بناءً على `user.branch_id`
- تعطيل اختيار الفرع لمدير الفرع

#### المشكلة 4: عدم وجود Error Logging
**الوصف:** لم يكن هناك logging للأخطاء في الـ console
**الإصلاح:** إضافة `console.log` و `console.error` للتتبع

#### المشكلة 5: عدم تصفية المرتجعات لمدير الفرع
**الوصف:** مدير الفرع كان يرى جميع المرتجعات بدلاً من مرتجعات فرعه فقط
**الإصلاح:** إضافة filter بناءً على `from_branch_id` لمدير الفرع

## الملفات المُعدلة

### 1. `restaurant-react/src/pages/returns/BranchReturnForm.tsx`
- إضافة validation للـ `user.id`
- إضافة validation للـ `return_reason`
- تعيين الفرع تلقائياً لمدير الفرع
- تعطيل اختيار الفرع لمدير الفرع
- إضافة error logging

### 2. `restaurant-react/src/pages/returns/ReturnsList.tsx`
- إضافة error logging للـ query

## اختبار الحل

### سيناريو 1: مدير الفرع يعمل مرتجع جديد
1. تسجيل الدخول كـ `branch1_sup` (branch1@restaurant.com)
2. الذهاب إلى المرتجعات
3. الضغط على "مرتجع للرئيسي"
4. التأكد من:
   - الفرع محدد تلقائياً (Branch 1)
   - لا يمكن تغيير الفرع
   - سبب الإرجاع مطلوب
5. إضافة صنف وحفظ
6. التأكد من ظهور المرتجع في القائمة

### سيناريو 2: التحقق من الأخطاء
1. فتح Developer Console (F12)
2. محاولة إنشاء مرتجع بدون سبب
3. التأكد من ظهور رسالة خطأ
4. التحقق من الـ console logs

## البيانات الموجودة في قاعدة البيانات

| Return Number | Status | From Branch | To Branch |
|--------------|--------|-------------|-----------|
| BRT-2024-12-0001 | pending | Branch 1 | Main Warehouse |
| BRT-2024-12-0002 | in_transit | Branch 1 | Main Warehouse |
| BRT-2024-12-0003 | received | Branch 2 | Main Warehouse |
| BRT-2024-12-0004 | rejected | Branch 1 | Main Warehouse |
| BRT-2024-12-0005 | cancelled | Branch 2 | Main Warehouse |
| BRT-2024-12-0006 | received | Branch 1 | Main Warehouse |

## المستخدمين المتاحين للاختبار

| Username | Role | Branch |
|----------|------|--------|
| branch1_sup | branch_supervisor | Branch 1 |
| branch2_sup | branch_supervisor | Branch 2 |
| warehouse_mgr | warehouse_manager | Main Warehouse |
| admin | admin | Main Warehouse |

## ملاحظات إضافية

1. **الـ RLS غير مفعل:** هذا يعني أن جميع المستخدمين يمكنهم رؤية جميع المرتجعات. قد تحتاج لتفعيل RLS لتقييد الوصول.

2. **الـ Query صحيح:** الـ Supabase query يستخدم الـ foreign key references بشكل صحيح.

3. **البيانات موجودة:** تم التأكد من وجود بيانات في قاعدة البيانات وأن الـ joins تعمل بشكل صحيح.


---

## تحديث: مشكلة تضاعف الكمية (15 ديسمبر 2025)

### المشكلة المُبلغ عنها
عند استلام المرتجع، الكمية بتتضاعف - يعني لو محدد 1، بيتخصم 2 من الفرع ويتضاف 2 للمخزن الرئيسي.

### التحليل

#### فحص الـ Database Triggers
- لا يوجد triggers على جدول `branch_returns` تعمل update للـ inventory
- الـ trigger الوحيد على `branch_return_items` هو `trg_update_br_totals` وهو فقط لحساب الإجماليات

#### فحص الكود
- الـ inventory update يحصل فقط في `BranchReturnDetail.tsx` في function `handleReceive`
- الـ `returns.service.ts` فيه function `receiveBranchReturn` لكنها غير مستخدمة

#### تحليل الـ Logs
الـ logs بتقول:
```
Source branch BEFORE update: 9
Source branch WILL BE: 8
Dest branch BEFORE update: 43
Dest branch WILL BE: 44
```

لكن الـ UI كان بيعرض قيم مختلفة (Branch 1: 12, Main: 38)

### السبب المحتمل
1. الـ UI بيعرض قيم cached أو قديمة
2. أو فيه عمليات أخرى بتحصل على الـ inventory

### الإصلاحات المُطبقة

#### 1. إضافة Optimistic Locking
```typescript
const { data: updatedReturn, error: statusError } = await supabase
  .from('branch_returns')
  .update({ status: 'received', ... })
  .eq('id', returnData.id)
  .eq('status', 'in_transit') // Only update if still in_transit
  .select('id')
  .single()
```

#### 2. إضافة Double-Click Protection
```typescript
const isReceiving = useRef(false)
if (isReceiving.current) {
  console.warn('Already receiving, skipping duplicate call')
  return
}
```

#### 3. إضافة Status Check قبل المعالجة
```typescript
const { data: currentReturn } = await supabase
  .from('branch_returns')
  .select('status')
  .eq('id', returnData.id)
  .single()

if (!currentReturn || currentReturn.status !== 'in_transit') {
  console.warn('Return status is not in_transit, skipping')
  return
}
```

#### 4. إضافة Verification Step
بعد الـ inventory update، يتم التحقق من القيم النهائية:
```typescript
console.log('=== VERIFICATION ===')
for (const item of returnData.items) {
  const { data: finalSource } = await supabase
    .from('inventory')
    .select('quantity')
    .eq('branch_id', returnData.from_branch.id)
    .eq('item_id', item.item.id)
    .single()
  
  console.log(`${item.item.name_ar}: Source=${finalSource?.quantity}, Dest=${finalDest?.quantity}`)
}
```

### كيفية الاختبار

1. افتح Developer Console (F12)
2. اذهب لصفحة المخزون وسجل القيم الحالية
3. اذهب لصفحة المرتجعات واستلم مرتجع
4. راقب الـ console logs:
   - `=== RECEIVE PROCESS START ===`
   - `Processing: [item], qty: [qty]`
   - `Source: [before] -> [after]`
   - `Dest: [before] -> [after]`
   - `=== VERIFICATION ===`
   - `=== RECEIVE PROCESS COMPLETE ===`
5. ارجع لصفحة المخزون وتأكد من القيم

### ملفات SQL للتشخيص
- `database/fix_branch_returns_inventory.sql` - للتحقق من الـ triggers والـ transactions
