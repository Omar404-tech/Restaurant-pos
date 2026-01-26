# دعم الكسور العشرية في الكميات 🔢
# Decimal Quantities Support

## 🎯 الهدف - Goal

تفعيل دعم الكسور العشرية في جميع حقول الكميات في النظام، مما يسمح بإدخال قيم مثل:
- **19.200** كجم لحمة
- **5.750** لتر زيت  
- **100.125** كجم دقيق

Enable decimal support for all quantity fields in the system, allowing values like:
- **19.200** kg meat
- **5.750** liter oil
- **100.125** kg flour

---

## ✅ الحالة الحالية - Current Status

### قاعدة البيانات - Database ✓
- ✅ **جاهزة بالكامل** - Fully ready
- ✅ تستخدم `numeric(12,3)` لجميع حقول الكميات
- ✅ تدعم حتى 3 أرقام عشرية
- ✅ جميع الجداول محدثة

### الواجهة الأمامية - Frontend ⏳
- ⏳ **تحتاج تحديث** - Needs update
- ⏳ معظم الحقول تستخدم `min="1"` بدون `step`
- ⏳ يجب إضافة `step="0.001"` لجميع حقول الكميات

---

## 🚀 خطوات التنفيذ السريعة - Quick Implementation Steps

### الخطوة 1: تحديث قاعدة البيانات (اختياري)
```bash
# تشغيل سكريبت التحقق والاختبار
# Run verification and test script
psql -U your_user -d your_database -f database/enable_decimal_quantities.sql
```

### الخطوة 2: تحديث الواجهة الأمامية (مطلوب)

#### الطريقة الأولى: تحديث تلقائي (موصى به)
```bash
# تشغيل سكريبت التحديث التلقائي
# Run automatic update script
cd restaurant-react
node ../scripts/update_quantity_inputs.js
```

#### الطريقة الثانية: تحديث يدوي
افتح كل ملف من القائمة أدناه وقم بتحديث حقول الكميات:

**قبل:**
```tsx
<input type="number" min="1" value={quantity} />
```

**بعد:**
```tsx
<input type="number" min="0.001" step="0.001" value={quantity} />
```

### الخطوة 3: استخدام الدوال المساعدة

```tsx
import { formatQuantity, parseQuantity, isValidQuantity } from '@/lib/utils';

// في المكون
const [quantity, setQuantity] = useState<number>(0);

// عند العرض
<div>الكمية: {formatQuantity(quantity)}</div>

// عند الإدخال
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
  placeholder="مثال: 19.200"
/>
```

---

## 📁 الملفات المطلوب تحديثها - Files to Update

### ✅ تم التحديث - Updated
- [x] `restaurant-react/src/lib/utils.ts` - إضافة دوال مساعدة

### ⏳ يحتاج تحديث - Needs Update

#### المخزون - Inventory
- [ ] `restaurant-react/src/pages/inventory/ItemForm.tsx`
- [ ] `restaurant-react/src/pages/inventory/DailyCountForm.tsx`
- [ ] `restaurant-react/src/pages/inventory/ChefConsumptionForm.tsx`
- [ ] `restaurant-react/src/pages/inventory/BranchStock.tsx`

#### التحويلات - Transfers
- [ ] `restaurant-react/src/pages/transfers/TransferForm.tsx`

#### التوريدات - Supplies
- [ ] `restaurant-react/src/pages/suppliers/SupplyForm.tsx`

#### المرتجعات - Returns
- [ ] `restaurant-react/src/pages/returns/BranchReturnForm.tsx`
- [ ] `restaurant-react/src/pages/returns/SupplierReturnForm.tsx`

#### طلبات الشراء - Purchase Orders
- [ ] `restaurant-react/src/pages/purchase/PurchaseOrderForm.tsx`
- [ ] `restaurant-react/src/pages/purchase/PurchaseRequestForm.tsx`

#### التلفيات - Damages
- [ ] `restaurant-react/src/pages/damages/DamageForm.tsx`

#### الوصفات - Recipes
- [ ] `restaurant-react/src/pages/recipes/ProduceRecipe.tsx`

---

## 🧪 الاختبار - Testing

### اختبار قاعدة البيانات
```sql
-- اختبار إدخال كمية عشرية
INSERT INTO inventory (branch_id, item_id, quantity) 
VALUES ('branch-uuid', 'item-uuid', 19.200);

-- التحقق من التخزين الصحيح
SELECT quantity, format_quantity(quantity) as formatted 
FROM inventory 
WHERE quantity = 19.200;
```

### اختبار الواجهة
قم باختبار السيناريوهات التالية في كل نموذج:

1. ✅ إدخال كمية صحيحة: `19`
2. ✅ إدخال كمية بكسر واحد: `19.2`
3. ✅ إدخال كمية بكسرين: `19.20`
4. ✅ إدخال كمية بثلاثة كسور: `19.200`
5. ✅ إدخال كمية صغيرة: `0.125`
6. ✅ إدخال كمية كبيرة: `999999.999`
7. ❌ محاولة إدخال قيمة سالبة (يجب أن تُرفض)
8. ❌ محاولة إدخال صفر (يجب أن تُرفض)

---

## 📚 الدوال المساعدة - Helper Functions

### `formatQuantity(quantity)`
تنسيق الكميات بإزالة الأصفار الزائدة

```typescript
formatQuantity(19.200)  // => "19.2"
formatQuantity(5.000)   // => "5"
formatQuantity(100.125) // => "100.125"
```

### `parseQuantity(value)`
تحليل الكمية من النص (يدعم الفاصلة العربية)

```typescript
parseQuantity("19.2")   // => 19.2
parseQuantity("19,2")   // => 19.2 (Arabic comma)
parseQuantity("")       // => 0
```

### `isValidQuantity(quantity, allowZero?)`
التحقق من صحة الكمية

```typescript
isValidQuantity(19.2)           // => true
isValidQuantity(0)              // => false
isValidQuantity(0, true)        // => true (allow zero)
isValidQuantity(-5)             // => false
isValidQuantity(999999999.999)  // => true
isValidQuantity(9999999999)     // => false (too large)
```

### `roundQuantity(quantity)`
تقريب الكمية إلى 3 أرقام عشرية

```typescript
roundQuantity(19.2005)  // => 19.201
roundQuantity(19.2004)  // => 19.200
```

### `formatQuantityWithUnit(quantity, unit)`
تنسيق الكمية مع الوحدة

```typescript
formatQuantityWithUnit(19.2, "كجم")  // => "19.2 كجم"
formatQuantityWithUnit(5, "لتر")     // => "5 لتر"
```

---

## 💡 أمثلة الاستخدام - Usage Examples

### مثال 1: نموذج إدخال بسيط
```tsx
import { useState } from 'react';
import { formatQuantity, parseQuantity, isValidQuantity } from '@/lib/utils';

function QuantityInput() {
  const [quantity, setQuantity] = useState<number>(0);
  const [error, setError] = useState<string>('');

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    const parsed = parseQuantity(value);
    
    if (value && !isValidQuantity(parsed)) {
      setError('الكمية غير صحيحة');
    } else {
      setError('');
      setQuantity(parsed);
    }
  };

  return (
    <div>
      <label>الكمية</label>
      <input
        type="number"
        min="0.001"
        step="0.001"
        value={quantity}
        onChange={handleChange}
        placeholder="مثال: 19.200"
      />
      {error && <span className="text-red-500">{error}</span>}
      <p>الكمية المنسقة: {formatQuantity(quantity)}</p>
    </div>
  );
}
```

### مثال 2: عرض الكميات في جدول
```tsx
import { formatQuantity, formatQuantityWithUnit } from '@/lib/utils';

function InventoryTable({ items }) {
  return (
    <table>
      <thead>
        <tr>
          <th>الصنف</th>
          <th>الكمية</th>
          <th>الوحدة</th>
        </tr>
      </thead>
      <tbody>
        {items.map(item => (
          <tr key={item.id}>
            <td>{item.name_ar}</td>
            <td>{formatQuantity(item.quantity)}</td>
            <td>{item.unit_ar}</td>
            {/* أو استخدم */}
            <td>{formatQuantityWithUnit(item.quantity, item.unit_ar)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

### مثال 3: حساب الإجمالي
```tsx
import { roundQuantity, formatQuantity } from '@/lib/utils';

function calculateTotal(items: Array<{quantity: number, price: number}>) {
  const total = items.reduce((sum, item) => {
    return sum + (item.quantity * item.price);
  }, 0);
  
  return roundQuantity(total);
}

// الاستخدام
const items = [
  { quantity: 19.200, price: 250 },
  { quantity: 5.750, price: 80 },
];

const total = calculateTotal(items);
console.log(formatQuantity(total)); // => "5,260"
```

---

## ⚠️ ملاحظات مهمة - Important Notes

### 1. الدقة العشرية
- قاعدة البيانات: `numeric(12,3)` - 3 أرقام عشرية
- الوصفات: `numeric(12,4)` - 4 أرقام عشرية (دقة أعلى)

### 2. القيود
- الحد الأدنى: `0.001` (لا يمكن إدخال صفر أو قيم سالبة)
- الحد الأقصى: `999,999,999.999`

### 3. التنسيق
- استخدم `formatQuantity()` دائماً عند العرض
- لا تعرض الأصفار الزائدة: `19.200` → `19.2`

### 4. الإدخال
- دائماً أضف `step="0.001"` لحقول الكميات
- دائماً أضف `min="0.001"` لمنع القيم السالبة
- أضف `placeholder` توضيحي مثل "مثال: 19.200"

### 5. التحقق من الصحة
- استخدم `isValidQuantity()` قبل الحفظ
- تحقق من القيم في الـ backend أيضاً

---

## 🔍 استكشاف الأخطاء - Troubleshooting

### المشكلة: لا يمكن إدخال كسور
**الحل:** تأكد من إضافة `step="0.001"` للحقل

### المشكلة: الكمية تُحفظ كـ integer
**الحل:** تحقق من نوع البيانات في قاعدة البيانات (يجب أن يكون `numeric`)

### المشكلة: الأصفار الزائدة تظهر
**الحل:** استخدم `formatQuantity()` عند العرض

### المشكلة: الفاصلة العربية لا تعمل
**الحل:** استخدم `parseQuantity()` الذي يدعم الفاصلة العربية

---

## 📞 الدعم - Support

للمزيد من المعلومات، راجع:
- `DECIMAL_QUANTITIES_IMPLEMENTATION.md` - دليل التنفيذ الكامل
- `database/enable_decimal_quantities.sql` - سكريبت قاعدة البيانات
- `scripts/update_quantity_inputs.js` - سكريبت التحديث التلقائي
- `restaurant-react/src/lib/utils.ts` - الدوال المساعدة

---

**تاريخ الإنشاء**: 2026-01-22  
**الحالة**: جاهز للتنفيذ - Ready for Implementation  
**الأولوية**: عالية - High Priority
