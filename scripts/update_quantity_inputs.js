#!/usr/bin/env node

/**
 * سكريبت لتحديث جميع حقول إدخال الكميات لدعم الكسور العشرية
 * Script to update all quantity input fields to support decimal values
 * 
 * الاستخدام - Usage:
 * node scripts/update_quantity_inputs.js
 */

const fs = require('fs');
const path = require('path');

// الملفات التي تحتاج تحديث
// Files that need updating
const filesToUpdate = [
  'restaurant-react/src/pages/inventory/ItemForm.tsx',
  'restaurant-react/src/pages/inventory/DailyCountForm.tsx',
  'restaurant-react/src/pages/inventory/ChefConsumptionForm.tsx',
  'restaurant-react/src/pages/inventory/BranchStock.tsx',
  'restaurant-react/src/pages/transfers/TransferForm.tsx',
  'restaurant-react/src/pages/suppliers/SupplyForm.tsx',
  'restaurant-react/src/pages/returns/BranchReturnForm.tsx',
  'restaurant-react/src/pages/returns/SupplierReturnForm.tsx',
  'restaurant-react/src/pages/purchase/PurchaseOrderForm.tsx',
  'restaurant-react/src/pages/purchase/PurchaseRequestForm.tsx',
  'restaurant-react/src/pages/damages/DamageForm.tsx',
  'restaurant-react/src/pages/recipes/ProduceRecipe.tsx',
];

// الأنماط التي نبحث عنها
// Patterns to search for
const patterns = [
  {
    // Pattern 1: type="number" min="1" بدون step
    // Pattern 1: type="number" min="1" without step
    search: /(<input[^>]*type="number"[^>]*min="1"[^>]*)(>)/g,
    replace: (match, before, after) => {
      // تحقق إذا كان يحتوي على step بالفعل
      // Check if it already has step
      if (before.includes('step=')) {
        return match;
      }
      // أضف step="0.001" وغير min إلى "0.001"
      // Add step="0.001" and change min to "0.001"
      const updated = before
        .replace(/min="1"/, 'min="0.001"')
        .replace(/min='1'/, 'min="0.001"');
      return `${updated} step="0.001"${after}`;
    }
  },
  {
    // Pattern 2: type="number" بدون min أو step
    // Pattern 2: type="number" without min or step
    search: /(<input[^>]*type="number"[^>]*)(>)/g,
    replace: (match, before, after) => {
      // تحقق إذا كان يحتوي على step أو min بالفعل
      // Check if it already has step or min
      if (before.includes('step=') || before.includes('min=')) {
        return match;
      }
      // أضف min و step
      // Add min and step
      return `${before} min="0.001" step="0.001"${after}`;
    }
  }
];

// دالة لتحديث ملف واحد
// Function to update a single file
function updateFile(filePath) {
  const fullPath = path.join(process.cwd(), filePath);
  
  // تحقق من وجود الملف
  // Check if file exists
  if (!fs.existsSync(fullPath)) {
    console.log(`⚠️  الملف غير موجود - File not found: ${filePath}`);
    return false;
  }
  
  // قراءة محتوى الملف
  // Read file content
  let content = fs.readFileSync(fullPath, 'utf8');
  const originalContent = content;
  
  // تطبيق جميع الأنماط
  // Apply all patterns
  let changesMade = false;
  patterns.forEach(pattern => {
    const newContent = content.replace(pattern.search, pattern.replace);
    if (newContent !== content) {
      content = newContent;
      changesMade = true;
    }
  });
  
  // إذا تم إجراء تغييرات، احفظ الملف
  // If changes were made, save the file
  if (changesMade) {
    // إنشاء نسخة احتياطية
    // Create backup
    const backupPath = fullPath + '.backup';
    fs.writeFileSync(backupPath, originalContent, 'utf8');
    
    // حفظ الملف المحدث
    // Save updated file
    fs.writeFileSync(fullPath, content, 'utf8');
    
    console.log(`✅ تم تحديث - Updated: ${filePath}`);
    console.log(`   📦 نسخة احتياطية - Backup: ${filePath}.backup`);
    return true;
  } else {
    console.log(`ℹ️  لا يحتاج تحديث - No update needed: ${filePath}`);
    return false;
  }
}

// دالة رئيسية
// Main function
function main() {
  console.log('============================================');
  console.log('🔧 تحديث حقول الكميات لدعم الكسور العشرية');
  console.log('🔧 Updating quantity fields for decimal support');
  console.log('============================================\n');
  
  let updatedCount = 0;
  let notFoundCount = 0;
  let noChangeCount = 0;
  
  filesToUpdate.forEach(file => {
    const result = updateFile(file);
    if (result === true) {
      updatedCount++;
    } else if (result === false && fs.existsSync(path.join(process.cwd(), file))) {
      noChangeCount++;
    } else {
      notFoundCount++;
    }
  });
  
  console.log('\n============================================');
  console.log('📊 ملخص - Summary');
  console.log('============================================');
  console.log(`✅ تم التحديث - Updated: ${updatedCount} files`);
  console.log(`ℹ️  لا يحتاج تحديث - No change: ${noChangeCount} files`);
  console.log(`⚠️  غير موجود - Not found: ${notFoundCount} files`);
  console.log('============================================\n');
  
  if (updatedCount > 0) {
    console.log('💡 ملاحظة: تم إنشاء نسخ احتياطية بامتداد .backup');
    console.log('💡 Note: Backup files created with .backup extension');
    console.log('💡 يمكنك حذفها بعد التأكد من صحة التحديثات');
    console.log('💡 You can delete them after verifying the updates\n');
  }
}

// تشغيل السكريبت
// Run script
main();
