-- =====================================================
-- TEST DATA: Branch Returns System
-- Returns from Branches to Main Warehouse
-- =====================================================

-- =====================================================
-- SCENARIO BR1: Excess Stock Return from Branch 1
-- Status: PENDING (waiting for approval)
-- =====================================================

-- BR1.1: Create Branch Return Request
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, requested_by, requested_at)
SELECT 'BRT-2024-12-0001', CURRENT_DATE, fb.id, tb.id, 'pending', 
       'Excess stock after slow weekend sales',
       'Branch has excess chicken and beef that will expire soon',
       u.id, CURRENT_TIMESTAMP
FROM branches fb, branches tb, users u
WHERE fb.code = 'BR001' AND tb.code = 'MAIN' AND u.username = 'branch1_sup'
ON CONFLICT (return_number) DO NOTHING;

-- BR1.2: Add Return Items
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, unit_cost, total_value, item_reason, notes)
SELECT br.id, i.id, 5, 78.00, 390.00, 'Excess stock', 'Slow sales this week'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0001' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

INSERT INTO branch_return_items (return_id, item_id, requested_quantity, unit_cost, total_value, item_reason, notes)
SELECT br.id, i.id, 3, 245.00, 735.00, 'Near expiry', 'Expiring in 3 days'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0001' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- =====================================================
-- SCENARIO BR2: Quality Issue Return from Branch 1
-- Status: APPROVED and IN_TRANSIT
-- =====================================================

-- BR2.1: Create Branch Return Request
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, requested_by, requested_at, approved_by, approved_at, shipped_at)
SELECT 'BRT-2024-12-0002', CURRENT_DATE - INTERVAL '1 day', fb.id, tb.id, 'in_transit', 
       'Quality issue with tomatoes - some are overripe',
       'Tomatoes received were already soft, need to return before spoilage',
       (SELECT id FROM users WHERE username = 'branch1_sup'),
       CURRENT_TIMESTAMP - INTERVAL '1 day',
       (SELECT id FROM users WHERE username = 'warehouse_mgr'),
       CURRENT_TIMESTAMP - INTERVAL '12 hours',
       CURRENT_TIMESTAMP - INTERVAL '6 hours'
FROM branches fb, branches tb
WHERE fb.code = 'BR001' AND tb.code = 'MAIN'
ON CONFLICT (return_number) DO NOTHING;

-- BR2.2: Add Return Items with approved quantities
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, approved_quantity, shipped_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 10, 10, 10, 15.00, 150.00, 'Quality issue - overripe'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0002' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- =====================================================
-- SCENARIO BR3: Completed Return from Branch 2
-- Status: RECEIVED (fully completed)
-- =====================================================

-- BR3.1: Create Completed Branch Return
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, 
    requested_by, requested_at, 
    approved_by, approved_at, 
    shipped_at,
    received_by, received_at)
SELECT 'BRT-2024-12-0003', CURRENT_DATE - INTERVAL '3 days', fb.id, tb.id, 'received', 
       'Stock rebalancing - Branch 2 overstocked',
       'Returning excess items to main warehouse for redistribution',
       (SELECT id FROM users WHERE username = 'branch2_sup'),
       CURRENT_TIMESTAMP - INTERVAL '3 days',
       (SELECT id FROM users WHERE username = 'warehouse_mgr'),
       CURRENT_TIMESTAMP - INTERVAL '2 days 18 hours',
       CURRENT_TIMESTAMP - INTERVAL '2 days 12 hours',
       (SELECT id FROM users WHERE username = 'warehouse_mgr'),
       CURRENT_TIMESTAMP - INTERVAL '2 days'
FROM branches fb, branches tb
WHERE fb.code = 'BR002' AND tb.code = 'MAIN'
ON CONFLICT (return_number) DO NOTHING;

-- BR3.2: Add Return Items (fully received)
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, approved_quantity, shipped_quantity, received_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 15, 15, 15, 15, 78.00, 1170.00, 'Excess stock'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0003' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

INSERT INTO branch_return_items (return_id, item_id, requested_quantity, approved_quantity, shipped_quantity, received_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 20, 20, 20, 18, 8.00, 144.00, 'Slow moving - 2 damaged in transit'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0003' AND i.code = 'ITM008'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- BR3.3: Record Inventory Transactions for Completed Return
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, notes, reference_type, created_by)
SELECT b.id, i.id, 'transfer_in', 15, 70, 85, 78.00, 'Branch return BRT-2024-12-0003', 'branch_return', u.id
FROM branches b, items i, users u 
WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, notes, reference_type, created_by)
SELECT b.id, i.id, 'transfer_in', 18, 100, 118, 8.00, 'Branch return BRT-2024-12-0003', 'branch_return', u.id
FROM branches b, items i, users u 
WHERE b.code = 'MAIN' AND i.code = 'ITM008' AND u.username = 'warehouse_mgr';

-- BR3.4: Update Main Warehouse Inventory (add received items)
UPDATE inventory SET quantity = quantity + 15 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity + 18 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM008');

-- BR3.5: Update Branch 2 Inventory (deduct returned items)
UPDATE inventory SET quantity = quantity - 15 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR002') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity - 18 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'BR002') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM008');

-- =====================================================
-- SCENARIO BR4: Rejected Return from Branch 1
-- Status: REJECTED (insufficient reason)
-- =====================================================

-- BR4.1: Create Rejected Branch Return
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, 
    requested_by, requested_at, 
    rejected_by, rejected_at, rejection_reason)
SELECT 'BRT-2024-12-0004', CURRENT_DATE - INTERVAL '2 days', fb.id, tb.id, 'rejected', 
       'Want to return cooking oil',
       'We have too much oil',
       (SELECT id FROM users WHERE username = 'branch1_sup'),
       CURRENT_TIMESTAMP - INTERVAL '2 days',
       (SELECT id FROM users WHERE username = 'warehouse_mgr'),
       CURRENT_TIMESTAMP - INTERVAL '1 day 20 hours',
       'Oil is a stable item with long shelf life. Please use it for cooking. Return not justified.'
FROM branches fb, branches tb
WHERE fb.code = 'BR001' AND tb.code = 'MAIN'
ON CONFLICT (return_number) DO NOTHING;

-- BR4.2: Add Return Items (rejected)
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 10, 45.00, 450.00, 'Excess stock'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0004' AND i.code = 'ITM005'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- =====================================================
-- SCENARIO BR5: Cancelled Return from Branch 2
-- Status: CANCELLED (branch cancelled request)
-- =====================================================

-- BR5.1: Create Cancelled Branch Return
INSERT INTO branch_returns (return_number, return_date, from_branch_id, to_branch_id, status, return_reason, notes, 
    requested_by, requested_at)
SELECT 'BRT-2024-12-0005', CURRENT_DATE - INTERVAL '4 days', fb.id, tb.id, 'cancelled', 
       'Slow moving cheese',
       'Cancelled - found use for cheese in new menu item',
       (SELECT id FROM users WHERE username = 'branch2_sup'),
       CURRENT_TIMESTAMP - INTERVAL '4 days'
FROM branches fb, branches tb
WHERE fb.code = 'BR002' AND tb.code = 'MAIN'
ON CONFLICT (return_number) DO NOTHING;

-- BR5.2: Add Return Items (cancelled)
INSERT INTO branch_return_items (return_id, item_id, requested_quantity, unit_cost, total_value, item_reason)
SELECT br.id, i.id, 5, 120.00, 600.00, 'Slow moving'
FROM branch_returns br, items i 
WHERE br.return_number = 'BRT-2024-12-0005' AND i.code = 'ITM007'
ON CONFLICT ON CONSTRAINT uk_return_item DO NOTHING;

-- =====================================================
-- NOTIFICATIONS for Branch Returns
-- =====================================================

-- Notification: Pending return needs approval
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'pending_approval', 'Branch Return Pending', 
       'Branch return BRT-2024-12-0001 from Branch 1 is waiting for approval', 
       'normal', 'branch_return', FALSE
FROM users u, branches b WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- Notification: Return in transit
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'transfer_received', 'Branch Return In Transit', 
       'Branch return BRT-2024-12-0002 is on the way to Main Warehouse', 
       'normal', 'branch_return', FALSE
FROM users u, branches b WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- Notification: Return rejected
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'system', 'Branch Return Rejected', 
       'Your return request BRT-2024-12-0004 has been rejected. Reason: Oil is a stable item.', 
       'normal', 'branch_return', FALSE
FROM users u, branches b WHERE u.username = 'branch1_sup' AND b.code = 'BR001';

-- =====================================================
-- AUDIT LOGS for Branch Returns
-- =====================================================

-- Audit: Return created
INSERT INTO audit_logs (user_id, action, table_name, new_values, ip_address)
SELECT u.id, 'CREATE', 'branch_returns',
       '{"return_number": "BRT-2024-12-0001", "from_branch": "BR001", "to_branch": "MAIN", "reason": "Excess stock"}'::jsonb,
       '192.168.1.101'
FROM users u WHERE u.username = 'branch1_sup';

-- Audit: Return approved
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'branch_returns',
       '{"status": "pending"}'::jsonb,
       '{"status": "approved", "approved_by": "warehouse_mgr"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- Audit: Return received
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'branch_returns',
       '{"status": "in_transit"}'::jsonb,
       '{"status": "received", "received_by": "warehouse_mgr"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- Audit: Return rejected
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'branch_returns',
       '{"status": "pending"}'::jsonb,
       '{"status": "rejected", "rejection_reason": "Oil is a stable item"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';

-- =====================================================
-- VERIFICATION QUERIES
-- Run these to verify the test data
-- =====================================================

-- Check branch returns summary
-- SELECT return_number, status, return_reason, total_items, total_quantity, total_value 
-- FROM branch_returns ORDER BY return_date DESC;

-- Check branch return items
-- SELECT * FROM vw_branch_returns;

-- Check return reasons
-- SELECT code, name, name_ar FROM branch_return_reasons ORDER BY sort_order;
