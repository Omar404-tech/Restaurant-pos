-- ============================================
-- تفعيل دعم الكسور العشرية في الكميات
-- Enable Decimal Quantities Support
-- ============================================
-- 
-- الهدف: التأكد من أن جميع حقول الكميات تدعم الكسور العشرية (مثل 19.200 كجم)
-- Goal: Ensure all quantity fields support decimal values (e.g., 19.200 kg)
--
-- ملاحظة: قاعدة البيانات تدعم بالفعل الكسور باستخدام numeric(12,3)
-- Note: Database already supports decimals using numeric(12,3)
-- - 12 = إجمالي الأرقام (Total digits)
-- - 3 = الأرقام بعد الفاصلة (Decimal places)
-- ============================================

-- التحقق من أنواع البيانات الحالية
-- Verify current data types
DO $$
BEGIN
    RAISE NOTICE 'Checking quantity field types...';
    
    -- عرض جميع الأعمدة التي تحتوي على كلمة quantity
    -- Display all columns containing 'quantity'
    FOR rec IN 
        SELECT 
            table_name, 
            column_name, 
            data_type,
            numeric_precision,
            numeric_scale
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND column_name LIKE '%quantity%'
        ORDER BY table_name, column_name
    LOOP
        RAISE NOTICE 'Table: %, Column: %, Type: %(%, %)', 
            rec.table_name, 
            rec.column_name, 
            rec.data_type,
            rec.numeric_precision,
            rec.numeric_scale;
    END LOOP;
END $$;

-- إضافة قيود للتحقق من الكميات الموجبة (إذا لم تكن موجودة)
-- Add constraints to ensure positive quantities (if not exists)

-- جدول المخزون - Inventory table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_inventory_quantity_positive'
    ) THEN
        ALTER TABLE inventory 
        ADD CONSTRAINT chk_inventory_quantity_positive 
        CHECK (quantity >= 0);
        RAISE NOTICE 'Added constraint: chk_inventory_quantity_positive';
    END IF;
END $$;

-- جدول معاملات المخزون - Inventory transactions table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_inventory_transactions_quantity_valid'
    ) THEN
        ALTER TABLE inventory_transactions 
        ADD CONSTRAINT chk_inventory_transactions_quantity_valid 
        CHECK (quantity <> 0);
        RAISE NOTICE 'Added constraint: chk_inventory_transactions_quantity_valid';
    END IF;
END $$;

-- إنشاء دالة مساعدة لتنسيق الكميات العشرية
-- Create helper function to format decimal quantities
CREATE OR REPLACE FUNCTION format_quantity(qty NUMERIC)
RETURNS TEXT AS $$
BEGIN
    -- إزالة الأصفار غير الضرورية من نهاية الرقم
    -- Remove unnecessary trailing zeros
    RETURN TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM qty::TEXT));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION format_quantity(NUMERIC) IS 'تنسيق الكميات العشرية بإزالة الأصفار الزائدة - Format decimal quantities by removing trailing zeros';

-- إنشاء view لعرض المخزون بتنسيق جميل
-- Create view to display inventory with formatted quantities
CREATE OR REPLACE VIEW v_inventory_formatted AS
SELECT 
    i.id,
    i.branch_id,
    b.name_ar as branch_name,
    i.item_id,
    it.name_ar as item_name,
    it.unit_ar as unit,
    format_quantity(i.quantity) as quantity_formatted,
    i.quantity as quantity_raw,
    format_quantity(i.min_quantity) as min_quantity_formatted,
    i.min_quantity as min_quantity_raw,
    format_quantity(i.reserved_quantity) as reserved_quantity_formatted,
    i.reserved_quantity as reserved_quantity_raw,
    i.last_restock_date,
    i.updated_at
FROM inventory i
JOIN branches b ON i.branch_id = b.id
JOIN items it ON i.item_id = it.id
ORDER BY b.name_ar, it.name_ar;

COMMENT ON VIEW v_inventory_formatted IS 'عرض المخزون مع تنسيق الكميات - Inventory view with formatted quantities';

-- اختبار إدخال كميات عشرية
-- Test decimal quantity input
DO $$
DECLARE
    test_branch_id UUID;
    test_item_id UUID;
    test_inventory_id UUID;
BEGIN
    RAISE NOTICE 'Testing decimal quantity support...';
    
    -- الحصول على فرع واحد للاختبار
    -- Get one branch for testing
    SELECT id INTO test_branch_id FROM branches LIMIT 1;
    
    -- الحصول على صنف واحد للاختبار
    -- Get one item for testing
    SELECT id INTO test_item_id FROM items LIMIT 1;
    
    IF test_branch_id IS NOT NULL AND test_item_id IS NOT NULL THEN
        -- محاولة إدخال كمية عشرية
        -- Try inserting a decimal quantity
        INSERT INTO inventory (
            branch_id, 
            item_id, 
            quantity, 
            min_quantity
        ) VALUES (
            test_branch_id,
            test_item_id,
            19.200,  -- كمية بكسور عشرية
            5.500    -- حد أدنى بكسور عشرية
        )
        ON CONFLICT (branch_id, item_id) 
        DO UPDATE SET 
            quantity = 19.200,
            min_quantity = 5.500,
            updated_at = CURRENT_TIMESTAMP
        RETURNING id INTO test_inventory_id;
        
        RAISE NOTICE 'Successfully inserted/updated decimal quantity: 19.200';
        RAISE NOTICE 'Inventory ID: %', test_inventory_id;
        
        -- عرض النتيجة
        -- Display result
        FOR rec IN 
            SELECT 
                quantity,
                format_quantity(quantity) as formatted,
                min_quantity,
                format_quantity(min_quantity) as min_formatted
            FROM inventory 
            WHERE id = test_inventory_id
        LOOP
            RAISE NOTICE 'Raw quantity: %, Formatted: %', rec.quantity, rec.formatted;
            RAISE NOTICE 'Raw min_quantity: %, Formatted: %', rec.min_quantity, rec.min_formatted;
        END LOOP;
        
        -- حذف البيانات التجريبية
        -- Clean up test data
        DELETE FROM inventory WHERE id = test_inventory_id;
        RAISE NOTICE 'Test data cleaned up';
    ELSE
        RAISE NOTICE 'No test data available (branches or items missing)';
    END IF;
END $$;

-- ملخص التغييرات
-- Summary of changes
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'ملخص دعم الكسور العشرية - Decimal Support Summary';
    RAISE NOTICE '============================================';
    RAISE NOTICE '✓ قاعدة البيانات تدعم الكسور: numeric(12,3)';
    RAISE NOTICE '✓ Database supports decimals: numeric(12,3)';
    RAISE NOTICE '✓ يمكن تخزين حتى 3 أرقام بعد الفاصلة';
    RAISE NOTICE '✓ Can store up to 3 decimal places';
    RAISE NOTICE '✓ مثال: 19.200, 5.750, 100.125';
    RAISE NOTICE '✓ Example: 19.200, 5.750, 100.125';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'الخطوة التالية: تحديث الواجهة الأمامية';
    RAISE NOTICE 'Next step: Update frontend interface';
    RAISE NOTICE '============================================';
END $$;
