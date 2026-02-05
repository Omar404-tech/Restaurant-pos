# 🚀 Quick Reference - New Branches Setup

## Current Branch Structure

| Code | Name (Arabic) | Name (English) | Type | Status |
|------|---------------|----------------|------|--------|
| MAIN | المخزن الرئيسي | Main Warehouse | Warehouse | ✅ Active |
| BR01 | منفذ البيع الأول | Sales Outlet 1 | Branch | ✅ Active |
| BR02 | منفذ البيع الثاني | Sales Outlet 2 | Branch | ✅ Active |
| **BR03** | **منفذ البيع الثالث** | **Sales Outlet 3** | **Branch** | **✅ Active** |
| **BR04** | **منفذ البيع الرابع** | **Sales Outlet 4** | **Branch** | **✅ Active** |

---

## 🎯 What Changed

### 1. New Branches Added
- **BR03** - منفذ البيع الثالث
- **BR04** - منفذ البيع الرابع

### 2. Branch Supervisor Default Page
- **Old:** Opens on Inventory page (المخزون)
- **New:** Opens on Transfers page (التحويلات)

### 3. Order Detail Page
- **Removed:** Print button (طباعة)
- **Kept:** Edit button (تعديل)

---

## 📋 To-Do Checklist

- [ ] Run `database/add_new_branches.sql` in Supabase
- [ ] Verify new branches appear in system
- [ ] Test branch supervisor login → should land on Transfers
- [ ] Check order detail page → no print button
- [ ] Create test transfer to new branches
- [ ] Assign users to new branches (if needed)

---

## 🔧 Quick Commands

### Check if branches were created:
```sql
SELECT code, name_ar, is_main_warehouse, status 
FROM branches 
ORDER BY code;
```

### Check inventory for new branches:
```sql
SELECT 
  b.code AS branch,
  COUNT(i.id) AS total_items,
  SUM(i.quantity) AS total_quantity
FROM branches b
LEFT JOIN inventory i ON b.id = i.branch_id
WHERE b.code IN ('BR03', 'BR04')
GROUP BY b.code;
```

### Assign user to new branch:
```sql
-- Update user's branch
UPDATE users 
SET branch_id = (SELECT id FROM branches WHERE code = 'BR03')
WHERE email = 'user@example.com';
```

---

## 👥 User Roles & Landing Pages

| Role | Arabic | Landing Page |
|------|--------|--------------|
| admin | مدير النظام | Dashboard |
| warehouse_manager | مدير المخزن | Inventory |
| **branch_supervisor** | **مشرف الفرع** | **Transfers** ⬅️ Changed |
| chef | شيف | POS Kitchen |
| cashier | كاشير | POS Cashier |
| purchase_manager | مدير المشتريات | Purchase |

---

## 📞 Support

If you encounter any issues:
1. Check the SQL script ran successfully
2. Verify React app is running latest code
3. Clear browser cache and reload
4. Check browser console for errors

---

**Last Updated:** February 2, 2026
