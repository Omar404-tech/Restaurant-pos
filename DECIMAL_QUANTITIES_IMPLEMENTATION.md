# دعم الكسور العشرية في الكميات
# Decimal Quantities Support Implementation

## 📋 نظرة عامة - Overview

تم تفعيل دعم الكسور العشرية في جميع حقول الكميات في النظام، مما يسمح بإدخال قيم مثل:
- **19.200** كجم لحمة
- **5.750** لتر زيت
- **100.125** كجم دقيق

---

## ✅ حالة قاعدة البيانات - Database Status

### ✓ مكتمل - Completed

قاعدة البيانات **تدعم بالفعل** الكسور العشرية باستخدام نوع البيانات `numeric(12,3)`:

```sql
-- جميع حقول الكميات تستخدم:
-- All quantity fields use:
numeric(12,3)
-- 12 = إجمالي الأرقام (Total digits)
-- 3 = الأرقام بعد الفاصلة (Decimal places)
```

### الجداول المتأثرة - Affected Tables

| الجدول - Table | الحقل - Field | النوع - Type |
|---------------|--------------|-------------|
| `inventory` | `quantity`, `min_quantity`, `reserved_quantity` | `numeric(12,3)` |
| `inventory_transactions` | `quantity`, `quantity_before`, `quantity_after` | `numeric(12,3)` |
| `inventory_batches` | `quantity`, `remaining_quantity` | `numeric(12,3)` |
| `supply_items` | `quantity`, `received_quantity` | `numeric(12,3)` |
| `transfer_items` | `requested_quantity`, `approved_quantity`, `shipped_quantity`, `received_quantity` | `numeric(12,3)` |
| `damages` | `quantity` | `numeric(12,3)` |
| `branch_return_items` | `requested_quantity`, `approved_quantity`, `shipped_quantity`, `received_quantity` | `numeric(12,3)` |
| `purchase_order_items` | `quantity`, `received_quantity` | `numeric(12,3)` |
| `purchase_request_items` | `requested_quantity`, `approved_quantity`, `ordered_quantity`, `received_quantity` | `numeric(12,3)` |
| `daily_inventory_count_items` | `system_quantity`, `actual_quantity` | `numeric(12,3)` |
| `recipe_ingredients` | `quantity` | `numeric(12,4)` ⭐ |

⭐ **ملاحظة**: جدول `recipe_ingredients` يدعم 4 أرقام عشرية لدقة أعلى في الوصفات

---

## 🔧 التغييرات المطلوبة في الواجهة - Frontend Changes Required

### 1. ملفات React التي تحتاج تحديث - React Files to Update

يجب تحديث جميع حقول إدخال الكميات لتقبل الكسور العشرية:

#### ✏️ التغيير المطلوب - Required Change

**قبل - Before:**
```tsx
<input 
  type="number" 
  min="1"
  // ❌ لا يوجد step - يمنع الكسور
  value={quantity}
  onChange={(e) => setQuantity(Number(e.target.value))}
/>
```

**بعد - After:**
```tsx
<input 
  type="number" 
  min="0.001"
  step="0.001"  // ✅ يسمح بإدخال 3 أرقام عشرية
  value={quantity}
  onChange={(e) => setQuantity(Number(e.target.value))}
/>
```

---

### 2. قائمة الملفات للتحديث - Files to Update

#### 📦 المخزون - Inventory
- [ ] `restaurant-react/src/pages/inventory/ItemForm.tsx`
- [ ] `restaurant-react/src/pages/inventory/DailyCountForm.tsx`
- [ ] `restaurant-react/src/pages/inventory/ChefConsumptionForm.tsx`
- [ ] `restaurant-react/src/pages/inventory/BranchStock.tsx`

#### 🔄 التحويلات - Transfers
- [ ] `restaurant-react/src/pages/transfers/TransferForm.tsx`

#### 📥 التوريدات - Supplies
- [ ] `restaurant-react/src/pages/suppliers/SupplyForm.tsx`

#### 🔙 المرتجعات - Returns
- [ ] `restaurant-react/src/pages/returns/BranchReturnForm.tsx`
- [ ] `restaurant-react/src/pages/returns/SupplierReturnForm.tsx`

#### 🛒 طلبات الشراء - Purchase Orders
- [ ] `restaurant-react/src/pages/purchase/PurchaseOrderForm.tsx`
- [ ] `restaurant-react/src/pages/purchase/PurchaseRequestForm.tsx`

#### 💔 التلفيات - Damages
- [ ] `restaurant-react/src/pages/damages/DamageForm.tsx`

#### 🍳 الوصفات - Recipes
- [ ] `restaurant-react/src/pages/recipes/RecipeForm.tsx` (يستخدم بالفعل `step="0.001"` ✅)
- [ ] `restaurant-react/src/pages/recipes/ProduceRecipe.tsx`

---

### 3. مثال تفصيلي للتحديث - Detailed Update Example

#### ملف: `TransferForm.tsx`

**الكود الحالي - Current Code:**
```tsx
<input 
  type="number" 
  min="1"  // ❌ يمنع الكسور
  value={item.requested_quantity}
  onChange={(e) => updateItem(index, 'requested_quantity', Number(e.target.value))}
  className="w-full px-3 py-2 border rounded-lg"
/>
```

**الكود المحدث - Updated Code:**
```tsx
<input 
  type="number" 
  min="0.001"      // ✅ الحد الأدنى 0.001
  step="0.001"     // ✅ يسمح بـ 3 أرقام عشرية
  value={item.requested_quantity}
  onChange={(e) => updateItem(index, 'requested_quantity', Number(e.target.value))}
  className="w-full px-3 py-2 border rounded-lg"
  placeholder="مثال: 19.200"  // ✅ مثال توضيحي
/>
```

---

### 4. دالة مساعدة للتنسيق - Helper Function for Formatting

أضف هذه الدالة في `restaurant-react/src/lib/utils.ts`:

```typescript
/**
 * تنسيق الكميات العشرية بإزالة الأصفار الزائدة
 * Format decimal quantities by removing trailing zeros
 * 
 * @example
 * formatQuantity(19.200) => "19.2"
 * formatQuantity(5.000) => "5"
 * formatQuantity(100.125) => "100.125"
 */
export function formatQuantity(quantity: number | string): string {
  const num = typeof quantity === 'string' ? parseFloat(quantity) : quantity;
  
  if (isNaN(num)) return '0';
  
  // تحويل إلى نص وإزالة الأصفار الزائدة
  // Convert to string and remove trailing zeros
  return num.toFixed(3).replace(/\.?0+$/, '');
}

/**
 * تحليل الكمية من النص
 * Parse quantity from text input
 * 
 * @example
 * parseQuantity("19.2") => 19.2
 * parseQuantity("19,2") => 19.2 (يدعم الفاصلة العربية)
 */
export function parseQuantity(value: string): number {
  // استبدال الفاصلة العربية بالنقطة
  // Replace Arabic comma with dot
  const normalized = value.replace(',', '.');
  const num = parseFloat(normalized);
  
  return isNaN(num) ? 0 : Math.max(0, num);
}

/**
 * التحقق من صحة الكمية
 * Validate quantity value
 */
export function isValidQuantity(quantity: number): boolean {
  return !isNaN(quantity) && quantity > 0 && quantity < 999999999;
}
```

---

### 5. استخدام الدوال المساعدة - Using Helper Functions

```tsx
import { formatQuantity, parseQuantity, isValidQuantity } from '@/lib/utils';

// في المكون - In component
const [quantity, setQuantity] = useState<number>(0);

// عند العرض - On display
<div>الكمية: {formatQuantity(quantity)}</div>

// عند الإدخال - On input
<input 
  type="number"
  min="0.001"
  step="0.001"
  value={quantity}
  onChange={(e) => {
    const newQty = parseQuantity(e.target.value);
    if (isValidQuantity(newQty)) {
      setQuantity(newQty);
    }
  }}
/>
```

---

## 🧪 الاختبار - Testing

### 1. اختبار قاعدة البيانات - Database Testing

```bash
# تشغيل سكريبت الاختبار
# Run test script
psql -U your_user -d your_database -f database/enable_decimal_quantities.sql
```

### 2. اختبار الواجهة - Frontend Testing

قم باختبار السيناريوهات التالية:

- [ ] إدخال كمية صحيحة: `19`
- [ ] إدخال كمية بكسر واحد: `19.2`
- [ ] إدخال كمية بكسرين: `19.20`
- [ ] إدخال كمية بثلاثة كسور: `19.200`
- [ ] إدخال كمية صغيرة: `0.125`
- [ ] إدخال كمية كبيرة: `999999.999`
- [ ] محاولة إدخال قيمة سالبة (يجب أن تُرفض)
- [ ] محاولة إدخال صفر (يجب أن تُرفض)

---

## 📊 أمثلة الاستخدام - Usage Examples

### مثال 1: توريد لحمة - Meat Supply
```
الصنف: لحمة بقري
الكمية: 19.200 كجم
السعر: 250.00 جنيه/كجم
الإجمالي: 4,800.00 جنيه
```

### مثال 2: تحويل زيت - Oil Transfer
```
الصنف: زيت ذرة
من الفرع: المخزن الرئيسي
إلى الفرع: فرع المعادي
الكمية: 5.750 لتر
```

### مثال 3: جرد يومي - Daily Count
```
الصنف: دقيق
الكمية في النظام: 100.000 كجم
الكمية الفعلية: 98.750 كجم
الفرق: -1.250 كجم
```

---

## ⚠️ ملاحظات مهمة - Important Notes

1. **الدقة العشرية - Decimal Precision**
   - قاعدة البيانات تخزن حتى 3 أرقام عشرية
   - الوصفات تدعم 4 أرقام عشرية لدقة أعلى

2. **التحقق من الصحة - Validation**
   - يجب أن تكون الكمية أكبر من صفر
   - يجب أن تكون الكمية أقل من 999,999,999.999

3. **العرض - Display**
   - استخدم `formatQuantity()` لإزالة الأصفار الزائدة
   - مثال: `19.200` يُعرض كـ `19.2`

4. **الإدخال - Input**
   - استخدم `step="0.001"` للسماح بـ 3 أرقام عشرية
   - استخدم `min="0.001"` لمنع القيم السالبة والصفر

5. **التوافق مع الأجهزة المحمولة - Mobile Compatibility**
   - `type="number"` يعرض لوحة مفاتيح رقمية على الهواتف
   - `inputMode="decimal"` يمكن استخدامه كبديل

---

## 🚀 خطوات التنفيذ - Implementation Steps

### المرحلة 1: قاعدة البيانات ✅
- [x] التحقق من دعم الكسور في قاعدة البيانات
- [x] إنشاء دوال مساعدة للتنسيق
- [x] إنشاء view للعرض المنسق
- [x] اختبار إدخال الكسور

### المرحلة 2: الواجهة الأمامية ⏳
- [ ] إضافة دوال مساعدة في `utils.ts`
- [ ] تحديث جميع حقول إدخال الكميات
- [ ] إضافة أمثلة توضيحية (placeholders)
- [ ] اختبار جميع النماذج

### المرحلة 3: الاختبار 🔜
- [ ] اختبار وحدات (Unit tests)
- [ ] اختبار تكامل (Integration tests)
- [ ] اختبار واجهة المستخدم (UI tests)
- [ ] اختبار الأداء (Performance tests)

---

## 📝 الخلاصة - Summary

✅ **قاعدة البيانات جاهزة** - Database is ready
- تدعم الكسور العشرية بالفعل
- لا حاجة لتغييرات في البنية

⏳ **الواجهة تحتاج تحديث** - Frontend needs update
- إضافة `step="0.001"` لجميع حقول الكميات
- تحديث `min` من `1` إلى `0.001`
- إضافة دوال مساعدة للتنسيق

🎯 **النتيجة المتوقعة** - Expected Result
- إمكانية إدخال كميات مثل 19.200
- عرض منسق بدون أصفار زائدة
- تجربة مستخدم محسّنة

---

## 📞 الدعم - Support

إذا واجهت أي مشاكل، تحقق من:
1. نوع البيانات في قاعدة البيانات: `numeric(12,3)`
2. خاصية `step` في حقول الإدخال: `step="0.001"`
3. التحقق من الصحة في الكود: `min="0.001"`

---

**تاريخ الإنشاء**: 2026-01-22
**الحالة**: جاهز للتنفيذ - Ready for Implementation
