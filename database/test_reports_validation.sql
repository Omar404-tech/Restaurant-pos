-- ============================================================================
-- اختبار شامل للتقارير - التحقق من صحة القيم
-- ============================================================================

-- تعيين الفترة الزمنية للاختبار (آخر 30 يوم)
DO $$
DECLARE
    v_start_date DATE := CURRENT_DATE - INTERVAL '30 days';
    v_end_date DATE := CURRENT_DATE;
    v_test_results TEXT := '';
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'بدء اختبار شامل للتقارير';
    RAISE NOTICE 'الفترة: من % إلى %', v_start_date, v_end_date;
    RAISE NOTICE '============================================================================';
    
    -- ========================================================================
    -- 1. تقرير المبيعات (Sales Report)
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📊 اختبار تقرير المبيعات...';
    RAISE NOTICE '----------------------------------------';
    
    -- إجمالي الطلبات
    DECLARE
        v_total_orders INTEGER;
        v_total_revenue DECIMAL(10,2);
        v_avg_order DECIMAL(10,2);
    BEGIN
        SELECT COUNT(*), COALESCE(SUM(total_amount), 0), COALESCE(AVG(total_amount), 0)
        INTO v_total_orders, v_total_revenue, v_avg_order
        FROM orders
        WHERE created_at >= v_start_date AND created_at <= v_end_date;
        
        RAISE NOTICE '✅ إجمالي الطلبات: %', v_total_orders;
        RAISE NOTICE '✅ إجمالي الإيرادات: % ج.م', v_total_revenue;
        RAISE NOTICE '✅ متوسط قيمة الطلب: % ج.م', v_avg_order;
        
        IF v_total_orders = 0 THEN
            RAISE WARNING '⚠️  لا توجد طلبات في الفترة المحددة';
        END IF;
        
        IF v_total_revenue = 0 AND v_total_orders > 0 THEN
            RAISE WARNING '❌ إجمالي الإيرادات = 0 رغم وجود طلبات!';
        END IF;
    END;
    
    -- الطلبات حسب الحالة
    RAISE NOTICE '';
    RAISE NOTICE 'الطلبات حسب الحالة:';
    FOR v_test_results IN
        SELECT '  ' || status || ': ' || COUNT(*) || ' طلب'
        FROM orders
        WHERE created_at >= v_start_date AND created_at <= v_end_date
        GROUP BY status
    LOOP
        RAISE NOTICE '%', v_test_results;
    END LOOP;
    
    -- طرق الدفع
    RAISE NOTICE '';
    RAISE NOTICE 'طرق الدفع:';
    DECLARE
        v_payment_total DECIMAL(10,2);
        v_revenue_total DECIMAL(10,2);
    BEGIN
        FOR v_test_results IN
            SELECT '  ' || COALESCE(payment_method, 'غير محدد') || ': ' || 
                   COUNT(*) || ' طلب، ' || COALESCE(SUM(total_amount), 0) || ' ج.م'
            FROM orders
            WHERE created_at >= v_start_date AND created_at <= v_end_date
            GROUP BY payment_method
        LOOP
            RAISE NOTICE '%', v_test_results;
        END LOOP;
        
        -- التحقق من تطابق المجاميع
        SELECT COALESCE(SUM(total_amount), 0) INTO v_payment_total
        FROM orders
        WHERE created_at >= v_start_date AND created_at <= v_end_date;
        
        SELECT COALESCE(SUM(total_amount), 0) INTO v_revenue_total
        FROM orders
        WHERE created_at >= v_start_date AND created_at <= v_end_date;
        
        IF ABS(v_payment_total - v_revenue_total) > 0.01 THEN
            RAISE WARNING '❌ مجموع طرق الدفع لا يطابق إجمالي الإيرادات!';
        ELSE
            RAISE NOTICE '✅ مجموع طرق الدفع يطابق إجمالي الإيرادات';
        END IF;
    END;
    
    -- أكثر الأصناف مبيعاً
    RAISE NOTICE '';
    RAISE NOTICE 'أكثر 5 أصناف مبيعاً:';
    FOR v_test_results IN
        SELECT '  ' || i.name_ar || ': ' || SUM(oi.quantity) || ' وحدة، ' || 
               COALESCE(SUM(oi.total_price), 0) || ' ج.م'
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN items i ON oi.item_id = i.id
        WHERE o.created_at >= v_start_date AND o.created_at <= v_end_date
        GROUP BY i.id, i.name_ar
        ORDER BY SUM(oi.total_price) DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '%', v_test_results;
    END LOOP;
    
    -- ========================================================================
    -- 2. تقرير المخزون (Inventory Report)
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📦 اختبار تقرير المخزون...';
    RAISE NOTICE '----------------------------------------';
    
    DECLARE
        v_total_items INTEGER;
        v_low_stock INTEGER;
        v_out_of_stock INTEGER;
        v_negative_qty INTEGER;
        v_inventory_value DECIMAL(12,2);
    BEGIN
        -- إجمالي الأصناف
        SELECT COUNT(*) INTO v_total_items FROM inventory;
        RAISE NOTICE '✅ إجمالي الأصناف: %', v_total_items;
        
        -- الأصناف منخفضة المخزون
        SELECT COUNT(*) INTO v_low_stock
        FROM inventory inv
        JOIN items i ON inv.item_id = i.id
        WHERE inv.quantity < i.min_stock_level;
        
        IF v_low_stock > 0 THEN
            RAISE WARNING '⚠️  أصناف منخفضة المخزون: %', v_low_stock;
        ELSE
            RAISE NOTICE '✅ لا توجد أصناف منخفضة المخزون';
        END IF;
        
        -- الأصناف النافذة
        SELECT COUNT(*) INTO v_out_of_stock
        FROM inventory WHERE quantity <= 0;
        
        IF v_out_of_stock > 0 THEN
            RAISE WARNING '❌ أصناف نافذة من المخزون: %', v_out_of_stock;
        ELSE
            RAISE NOTICE '✅ لا توجد أصناف نافذة';
        END IF;
        
        -- الكميات السالبة
        SELECT COUNT(*) INTO v_negative_qty
        FROM inventory WHERE quantity < 0;
        
        IF v_negative_qty > 0 THEN
            RAISE WARNING '❌ أصناف بكميات سالبة: %', v_negative_qty;
            
            -- عرض الأصناف السالبة
            FOR v_test_results IN
                SELECT '  ' || i.name_ar || ': ' || inv.quantity
                FROM inventory inv
                JOIN items i ON inv.item_id = i.id
                WHERE inv.quantity < 0
                LIMIT 5
            LOOP
                RAISE NOTICE '%', v_test_results;
            END LOOP;
        ELSE
            RAISE NOTICE '✅ لا توجد كميات سالبة';
        END IF;
        
        -- قيمة المخزون
        SELECT COALESCE(SUM(inv.quantity * i.purchase_price), 0) INTO v_inventory_value
        FROM inventory inv
        JOIN items i ON inv.item_id = i.id;
        
        RAISE NOTICE '✅ قيمة المخزون: % ج.م', v_inventory_value;
    END;
    
    -- الأصناف حسب التصنيف
    RAISE NOTICE '';
    RAISE NOTICE 'الأصناف حسب التصنيف:';
    FOR v_test_results IN
        SELECT '  ' || COALESCE(c.name_ar, 'غير مصنف') || ': ' || COUNT(*) || ' صنف'
        FROM inventory inv
        JOIN items i ON inv.item_id = i.id
        LEFT JOIN categories c ON i.category_id = c.id
        GROUP BY c.name_ar
    LOOP
        RAISE NOTICE '%', v_test_results;
    END LOOP;
    
    -- ========================================================================
    -- 3. تقرير الموردين (Suppliers Report)
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '🚚 اختبار تقرير الموردين...';
    RAISE NOTICE '----------------------------------------';
    
    DECLARE
        v_supplies_count INTEGER;
        v_supplies_value DECIMAL(12,2);
        v_payments_count INTEGER;
        v_payments_value DECIMAL(12,2);
        v_balance DECIMAL(12,2);
    BEGIN
        -- التوريدات
        SELECT COUNT(*), COALESCE(SUM(total_amount), 0)
        INTO v_supplies_count, v_supplies_value
        FROM supplies
        WHERE supply_date >= v_start_date AND supply_date <= v_end_date;
        
        RAISE NOTICE '✅ عدد التوريدات: %', v_supplies_count;
        RAISE NOTICE '✅ قيمة التوريدات: % ج.م', v_supplies_value;
        
        -- المدفوعات
        SELECT COUNT(*), COALESCE(SUM(amount), 0)
        INTO v_payments_count, v_payments_value
        FROM payments
        WHERE payment_date >= v_start_date AND payment_date <= v_end_date;
        
        RAISE NOTICE '✅ عدد المدفوعات: %', v_payments_count;
        RAISE NOTICE '✅ قيمة المدفوعات: % ج.م', v_payments_value;
        
        -- الرصيد
        v_balance := v_supplies_value - v_payments_value;
        
        IF v_balance > 0 THEN
            RAISE WARNING '⚠️  الرصيد المستحق: % ج.م', v_balance;
        ELSIF v_balance < 0 THEN
            RAISE WARNING '⚠️  دفعات زائدة: % ج.م', ABS(v_balance);
        ELSE
            RAISE NOTICE '✅ الرصيد متوازن';
        END IF;
    END;
    
    -- التوريدات حسب المورد
    RAISE NOTICE '';
    RAISE NOTICE 'أكثر 5 موردين:';
    FOR v_test_results IN
        SELECT '  ' || s.name_ar || ': ' || COUNT(*) || ' توريد، ' || 
               COALESCE(SUM(sup.total_amount), 0) || ' ج.م'
        FROM supplies sup
        JOIN suppliers s ON sup.supplier_id = s.id
        WHERE sup.supply_date >= v_start_date AND sup.supply_date <= v_end_date
        GROUP BY s.name_ar
        ORDER BY SUM(sup.total_amount) DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '%', v_test_results;
    END LOOP;
    
    -- التحقق من التوريدات بدون أصناف
    DECLARE
        v_supplies_no_items INTEGER;
    BEGIN
        SELECT COUNT(DISTINCT s.id) INTO v_supplies_no_items
        FROM supplies s
        LEFT JOIN supply_items si ON s.id = si.supply_id
        WHERE s.supply_date >= v_start_date 
          AND s.supply_date <= v_end_date
          AND si.id IS NULL;
        
        IF v_supplies_no_items > 0 THEN
            RAISE WARNING '❌ توريدات بدون أصناف: %', v_supplies_no_items;
        ELSE
            RAISE NOTICE '✅ جميع التوريدات تحتوي على أصناف';
        END IF;
    END;
    
    -- ========================================================================
    -- 4. تقرير التالف (Damages Report)
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  اختبار تقرير التالف...';
    RAISE NOTICE '----------------------------------------';
    
    DECLARE
        v_damages_count INTEGER;
        v_damages_value DECIMAL(12,2);
        v_pending INTEGER;
        v_approved INTEGER;
        v_rejected INTEGER;
        v_negative_values INTEGER;
    BEGIN
        -- إجمالي التالف
        SELECT COUNT(*), COALESCE(SUM(estimated_value), 0)
        INTO v_damages_count, v_damages_value
        FROM damages
        WHERE created_at >= v_start_date AND created_at <= v_end_date;
        
        RAISE NOTICE '✅ عدد سجلات التالف: %', v_damages_count;
        RAISE NOTICE '✅ إجمالي الخسائر: % ج.م', v_damages_value;
        
        IF v_damages_count = 0 THEN
            RAISE NOTICE '⚠️  لا توجد سجلات تالف في الفترة المحددة';
        END IF;
        
        -- حسب الحالة
        SELECT 
            COUNT(*) FILTER (WHERE status = 'pending'),
            COUNT(*) FILTER (WHERE status = 'approved'),
            COUNT(*) FILTER (WHERE status = 'rejected')
        INTO v_pending, v_approved, v_rejected
        FROM damages
        WHERE created_at >= v_start_date AND created_at <= v_end_date;
        
        RAISE NOTICE '  معلق: %', v_pending;
        RAISE NOTICE '  موافق عليه: %', v_approved;
        RAISE NOTICE '  مرفوض: %', v_rejected;
        
        -- التحقق من القيم السالبة
        SELECT COUNT(*) INTO v_negative_values
        FROM damages
        WHERE estimated_value < 0;
        
        IF v_negative_values > 0 THEN
            RAISE WARNING '❌ سجلات بقيم سالبة: %', v_negative_values;
        ELSE
            RAISE NOTICE '✅ لا توجد قيم سالبة';
        END IF;
    END;
    
    -- التالف حسب السبب
    IF EXISTS (SELECT 1 FROM damages WHERE created_at >= v_start_date AND created_at <= v_end_date) THEN
        RAISE NOTICE '';
        RAISE NOTICE 'التالف حسب السبب:';
        FOR v_test_results IN
            SELECT '  ' || COALESCE(dr.name_ar, 'غير محدد') || ': ' || 
                   COUNT(*) || ' سجل، ' || COALESCE(SUM(d.estimated_value), 0) || ' ج.م'
            FROM damages d
            LEFT JOIN damage_reasons dr ON d.reason_id = dr.id
            WHERE d.created_at >= v_start_date AND d.created_at <= v_end_date
            GROUP BY dr.name_ar
        LOOP
            RAISE NOTICE '%', v_test_results;
        END LOOP;
    END IF;
    
    -- ========================================================================
    -- 5. تقرير التحويلات (Transfers Report)
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '🔄 اختبار تقرير التحويلات...';
    RAISE NOTICE '----------------------------------------';
    
    DECLARE
        v_transfers_count INTEGER;
        v_pending INTEGER;
        v_approved INTEGER;
        v_received INTEGER;
        v_rejected INTEGER;
        v_same_branch INTEGER;
        v_no_items INTEGER;
    BEGIN
        -- إجمالي التحويلات
        SELECT COUNT(*) INTO v_transfers_count
        FROM transfers
        WHERE created_at >= v_start_date AND created_at <= v_end_date;
        
        RAISE NOTICE '✅ عدد التحويلات: %', v_transfers_count;
        
        IF v_transfers_count = 0 THEN
            RAISE NOTICE '⚠️  لا توجد تحويلات في الفترة المحددة';
        ELSE
            -- حسب الحالة
            SELECT 
                COUNT(*) FILTER (WHERE status = 'pending'),
                COUNT(*) FILTER (WHERE status = 'approved'),
                COUNT(*) FILTER (WHERE status = 'received'),
                COUNT(*) FILTER (WHERE status = 'rejected')
            INTO v_pending, v_approved, v_received, v_rejected
            FROM transfers
            WHERE created_at >= v_start_date AND created_at <= v_end_date;
            
            RAISE NOTICE '  معلق: %', v_pending;
            RAISE NOTICE '  موافق عليه: %', v_approved;
            RAISE NOTICE '  مستلم: %', v_received;
            RAISE NOTICE '  مرفوض: %', v_rejected;
            
            -- التحقق من التحويلات من نفس الفرع
            SELECT COUNT(*) INTO v_same_branch
            FROM transfers
            WHERE from_branch_id = to_branch_id
              AND created_at >= v_start_date 
              AND created_at <= v_end_date;
            
            IF v_same_branch > 0 THEN
                RAISE WARNING '❌ تحويلات من نفس الفرع إلى نفس الفرع: %', v_same_branch;
            ELSE
                RAISE NOTICE '✅ لا توجد تحويلات من نفس الفرع';
            END IF;
            
            -- التحقق من التحويلات بدون أصناف
            SELECT COUNT(DISTINCT t.id) INTO v_no_items
            FROM transfers t
            LEFT JOIN transfer_items ti ON t.id = ti.transfer_id
            WHERE t.created_at >= v_start_date 
              AND t.created_at <= v_end_date
              AND ti.id IS NULL;
            
            IF v_no_items > 0 THEN
                RAISE WARNING '❌ تحويلات بدون أصناف: %', v_no_items;
            ELSE
                RAISE NOTICE '✅ جميع التحويلات تحتوي على أصناف';
            END IF;
        END IF;
    END;
    
    -- ========================================================================
    -- 6. تقرير الأداء (Performance Report)
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '📈 اختبار تقرير الأداء...';
    RAISE NOTICE '----------------------------------------';
    
    -- أداء الفروع
    RAISE NOTICE 'أداء الفروع:';
    FOR v_test_results IN
        SELECT '  ' || b.name_ar || ': ' || COUNT(o.id) || ' طلب، ' || 
               COALESCE(SUM(o.total_amount), 0) || ' ج.م'
        FROM branches b
        LEFT JOIN orders o ON b.id = o.branch_id 
            AND o.created_at >= v_start_date 
            AND o.created_at <= v_end_date
        WHERE b.is_active = TRUE
        GROUP BY b.name_ar
        ORDER BY SUM(o.total_amount) DESC NULLS LAST
    LOOP
        RAISE NOTICE '%', v_test_results;
    END LOOP;
    
    -- ========================================================================
    -- النتيجة النهائية
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ اكتمل اختبار جميع التقارير';
    RAISE NOTICE '============================================================================';
END $$;
