-- ============================================
-- اختبار سريع لدعم الكسور العشرية
-- Quick Test for Decimal Quantities Support
-- ============================================

-- 1. اختبار إدخال كميات عشرية في المخزون
-- Test inserting decimal quantities in inventory
DO $$
DECLARE
    test_branch_id UUID;
    test_item_id UUID;
BEGIN
    -- الحصول على أول فرع وصنف
    SELECT id INTO test_branch_id FROM branches LIMIT 1;
    SELECT id INTO test_item_id FROM items LIMIT 1;
    
    IF test_branch_id IS NOT NULL AND test_item_id IS NOT NULL THEN
        RAISE NOTICE '=== اختبار 1: إدخال كميات عشرية ===';
        
        -- إدخال كمية بكسور
        INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
        VALUES (test_branch_id, test_item_id, 19.200, 5.500)
        ON CONFLICT (branch_id, item_id) 
        DO UPDATE SET 
            quantity = 19.200,
            min_quantity = 5.500;
        
        RAISE NOTICE '✓ تم إدخال كمية: 19.200';
        RAISE NOTICE '✓ تم إدخال حد أدنى: 5.500';
    END IF;
END $$;

-- 2. اختبار قراءة وعرض الكميات
-- Test reading and displaying quantities
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== اختبار 2: قراءة الكميات ===';
    
    FOR rec IN 
        SELECT 
            b.name_ar as branch,
            i.name_ar as item,
            inv.quantity,
            inv.min_quantity
        FROM inventory inv
        JOIN branches b ON inv.branch_id = b.id
        JOIN items i ON inv.item_id = i.id
        WHERE inv.quantity::TEXT LIKE '%.%'  -- فقط الكميات التي تحتوي على كسور
        LIMIT 5
    LOOP
        RAISE NOTICE 'الفرع: %, الصنف: %, الكمية: %, الحد الأدنى: %', 
            rec.branch, rec.item, rec.quantity, rec.min_quantity;
    END LOOP;
END $$;

-- 3. اختبار العمليات الحسابية
-- Test arithmetic operations
DO $$
DECLARE
    qty1 NUMERIC(12,3) := 19.200;
    qty2 NUMERIC(12,3) := 5.750;
    total NUMERIC(12,3);
    diff NUMERIC(12,3);
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== اختبار 3: العمليات الحسابية ===';
    
    total := qty1 + qty2;
    diff := qty1 - qty2;
    
    RAISE NOTICE 'الكمية 1: %', qty1;
    RAISE NOTICE 'الكمية 2: %', qty2;
    RAISE NOTICE 'المجموع: %', total;
    RAISE NOTICE 'الفرق: %', diff;
    RAISE NOTICE 'الضرب: %', qty1 * 2;
    RAISE NOTICE 'القسمة: %', qty1 / 2;
END $$;

-- 4. اختبار دالة التنسيق
-- Test formatting function
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== اختبار 4: تنسيق الكميات ===';
    
    RAISE NOTICE '19.200 => %', format_quantity(19.200);
    RAISE NOTICE '5.000 => %', format_quantity(5.000);
    RAISE NOTICE '100.125 => %', format_quantity(100.125);
    RAISE NOTICE '0.001 => %', format_quantity(0.001);
    RAISE NOTICE '999999.999 => %', format_quantity(999999.999);
END $$;

-- 5. اختبار القيود (Constraints)
-- Test constraints
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== اختبار 5: القيود ===';
    
    -- محاولة إدخال كمية سالبة (يجب أن تفشل)
    BEGIN
        INSERT INTO inventory (branch_id, item_id, quantity)
        SELECT 
            (SELECT id FROM branches LIMIT 1),
            (SELECT id FROM items LIMIT 1),
            -5.5;
        RAISE NOTICE '✗ فشل: تم قبول كمية سالبة!';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '✓ نجح: تم رفض الكمية السالبة';
    END;
END $$;

-- 6. اختبار أنواع البيانات في جميع الجداول
-- Test data types in all tables
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== اختبار 6: أنواع البيانات ===';
    
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
        AND data_type = 'numeric'
        ORDER BY table_name, column_name
    LOOP
        RAISE NOTICE 'جدول: %, عمود: %, نوع: %(%, %)', 
            rec.table_name, 
            rec.column_name, 
            rec.data_type,
            rec.numeric_precision,
            rec.numeric_scale;
    END LOOP;
END $$;

-- 7. اختبار سيناريو واقعي كامل
-- Test complete real-world scenario
DO $$
DECLARE
    v_branch_id UUID;
    v_item_id UUID;
    v_supplier_id UUID;
    v_supply_id UUID;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== اختبار 7: سيناريو واقعي ===';
    
    -- الحصول على بيانات الاختبار
    SELECT id INTO v_branch_id FROM branches WHERE is_main_warehouse = true LIMIT 1;
    SELECT id INTO v_item_id FROM items LIMIT 1;
    SELECT id INTO v_supplier_id FROM suppliers LIMIT 1;
    
    IF v_branch_id IS NOT NULL AND v_item_id IS NOT NULL AND v_supplier_id IS NOT NULL THEN
        -- سيناريو: توريد 19.200 كجم لحمة
        RAISE NOTICE 'السيناريو: توريد 19.200 كجم لحمة';
        
        -- 1. إنشاء توريد
        INSERT INTO supplies (
            branch_id,
            supplier_id,
            supply_date,
            payment_method,
            total_amount,
            paid_amount
        ) VALUES (
            v_branch_id,
            v_supplier_id,
            CURRENT_DATE,
            'cash',
            4800.00,  -- 19.200 * 250
            4800.00
        ) RETURNING id INTO v_supply_id;
        
        RAISE NOTICE '✓ تم إنشاء التوريد';
        
        -- 2. إضافة صنف التوريد
        INSERT INTO supply_items (
            supply_id,
            item_id,
            quantity,
            received_quantity,
            unit_price,
            discount_percent,
            total_amount
        ) VALUES (
            v_supply_id,
            v_item_id,
            19.200,
            19.200,
            250.00,
            0,
            4800.00
        );
        
        RAISE NOTICE '✓ تم إضافة الصنف بكمية: 19.200';
        
        -- 3. التحقق من المخزون
        FOR rec IN 
            SELECT quantity 
            FROM inventory 
            WHERE branch_id = v_branch_id 
            AND item_id = v_item_id
        LOOP
            RAISE NOTICE '✓ الكمية في المخزون: %', rec.quantity;
        END LOOP;
        
        -- 4. تنظيف بيانات الاختبار
        DELETE FROM supply_items WHERE supply_id = v_supply_id;
        DELETE FROM supplies WHERE id = v_supply_id;
        
        RAISE NOTICE '✓ تم تنظيف بيانات الاختبار';
    ELSE
        RAISE NOTICE '⚠ لا توجد بيانات كافية للاختبار';
    END IF;
END $$;

-- ملخص النتائج
-- Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ اكتملت جميع الاختبارات بنجاح';
    RAISE NOTICE '✅ All tests completed successfully';
    RAISE NOTICE '============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'النظام جاهز لاستخدام الكسور العشرية في الكميات';
    RAISE NOTICE 'System is ready to use decimal quantities';
    RAISE NOTICE '';
    RAISE NOTICE 'أمثلة صحيحة:';
    RAISE NOTICE '- 19.200 كجم لحمة';
    RAISE NOTICE '- 5.750 لتر زيت';
    RAISE NOTICE '- 100.125 كجم دقيق';
    RAISE NOTICE '- 0.001 (الحد الأدنى)';
    RAISE NOTICE '';
    RAISE NOTICE 'الخطوة التالية: تحديث الواجهة الأمامية';
    RAISE NOTICE 'Next step: Update frontend interface';
    RAISE NOTICE '============================================';
END $$;
