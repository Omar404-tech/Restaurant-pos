-- =====================================================
-- DEEP TEST SCENARIOS - Restaurant Management System
-- =====================================================

-- =====================================================
-- SCENARIO A: Complex Supply Chain Flow
-- Multiple supplies from same supplier with different payment terms
-- =====================================================

-- A.1: New Supply from SUP001 (Credit) - Large Order
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, received_by, received_at)
SELECT 'SUP-2024-003', s.id, b.id, 'INV-003', CURRENT_DATE, 8000.00, 1120.00, 9120.00, 'credit', 'pending', u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'SUP001' AND b.code = 'MAIN' AND u.username = 'warehouse_mgr'
ON CONFLICT (supply_number) DO NOTHING;

-- A.2: Supply Items for SUP-2024-003
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 50, 50, 78.00, 14, 4446.00, 'BATCH-005', CURRENT_DATE + INTERVAL '7 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-003' AND i.code = 'ITM001';

INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 20, 20, 245.00, 14, 5586.00, 'BATCH-006', CURRENT_DATE + INTERVAL '5 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-003' AND i.code = 'ITM002';

-- A.3: Update Supplier Balance
UPDATE suppliers SET current_balance = current_balance + 9120.00 WHERE code = 'SUP001';

-- A.4: Update Inventory
UPDATE inventory SET quantity = quantity + 50 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE inventory SET quantity = quantity + 20 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

-- A.5: Add Inventory Batches
INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-005', 50, 50, 78.00, CURRENT_DATE + INTERVAL '7 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-003'
WHERE b.code = 'MAIN' AND i.code = 'ITM001';

INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-006', 20, 20, 245.00, CURRENT_DATE + INTERVAL '5 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-003'
WHERE b.code = 'MAIN' AND i.code = 'ITM002';

-- A.6: Record Transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 50, 30, 80, 78.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 20, 10, 30, 245.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM002' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO B: Multiple Payments to Supplier
-- Testing partial payments and balance tracking
-- =====================================================

-- B.1: First Payment (Bank Transfer)
INSERT INTO supplier_payments (payment_number, supplier_id, amount, payment_method, reference_number, bank_name, payment_date, notes, created_by)
SELECT 'PAY-2024-002', s.id, 5000.00, 'bank_transfer', 'TRX-789012', 'CIB Bank', CURRENT_DATE, 'Second payment', u.id
FROM suppliers s, users u WHERE s.code = 'SUP001' AND u.username = 'admin'
ON CONFLICT (payment_number) DO NOTHING;

UPDATE suppliers SET current_balance = current_balance - 5000.00 WHERE code = 'SUP001';

-- B.2: Second Payment (Cash)
INSERT INTO supplier_payments (payment_number, supplier_id, amount, payment_method, payment_date, notes, created_by)
SELECT 'PAY-2024-003', s.id, 2000.00, 'cash', CURRENT_DATE, 'Cash payment', u.id
FROM suppliers s, users u WHERE s.code = 'SUP001' AND u.username = 'admin'
ON CONFLICT (payment_number) DO NOTHING;

UPDATE suppliers SET current_balance = current_balance - 2000.00 WHERE code = 'SUP001';

-- B.3: Third Payment (Check)
INSERT INTO supplier_payments (payment_number, supplier_id, amount, payment_method, reference_number, payment_date, notes, created_by)
SELECT 'PAY-2024-004', s.id, 1500.00, 'check', 'CHK-123456', CURRENT_DATE + INTERVAL '7 days', 'Post-dated check', u.id
FROM suppliers s, users u WHERE s.code = 'SUP001' AND u.username = 'admin'
ON CONFLICT (payment_number) DO NOTHING;

UPDATE suppliers SET current_balance = current_balance - 1500.00 WHERE code = 'SUP001';

-- =====================================================
-- SCENARIO C: Complex Transfer with Partial Approval
-- Transfer request with some items rejected
-- =====================================================

-- C.1: Create Transfer Request from Main to Branch 2
INSERT INTO transfers (transfer_number, from_branch_id, to_branch_id, status, priority, notes, requested_by, requested_at)
SELECT 'TRF-2024-002', b1.id, b2.id, 'pending', 2, 'Urgent request for Branch 2', u.id, CURRENT_TIMESTAMP
FROM branches b1, branches b2, users u
WHERE b1.code = 'MAIN' AND b2.code = 'BR002' AND u.username = 'admin'
ON CONFLICT (transfer_number) DO NOTHING;

-- C.2: Add Transfer Items (some will be partially approved)
INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 30, 'Need for weekend rush'
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-002' AND i.code = 'ITM001';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 15, NULL
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-002' AND i.code = 'ITM002';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 100, 'For salads'
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-002' AND i.code = 'ITM003';

INSERT INTO transfer_items (transfer_id, item_id, requested_quantity, notes)
SELECT t.id, i.id, 50, NULL
FROM transfers t, items i WHERE t.transfer_number = 'TRF-2024-002' AND i.code = 'ITM006';

-- C.3: Partial Approval (not enough stock for all)
UPDATE transfers SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'warehouse_mgr'),
    approved_at = CURRENT_TIMESTAMP
WHERE transfer_number = 'TRF-2024-002';

-- Approve with reduced quantities
UPDATE transfer_items SET approved_quantity = 25, shipped_quantity = 25
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-002')
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE transfer_items SET approved_quantity = 10, shipped_quantity = 10
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-002')
AND item_id = (SELECT id FROM items WHERE code = 'ITM002');

UPDATE transfer_items SET approved_quantity = 30, shipped_quantity = 30
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-002')
AND item_id = (SELECT id FROM items WHERE code = 'ITM003');

UPDATE transfer_items SET approved_quantity = 50, shipped_quantity = 50
WHERE transfer_id = (SELECT id FROM transfers WHERE transfer_number = 'TRF-2024-002')
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

-- =====================================================
-- SCENARIO D: Multiple Damages with Different Reasons
-- Testing damage workflow and inventory impact
-- =====================================================

-- D.1: Damage due to Transport
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-003', b.id, i.id, 5, 15.00, 75.00, dr.id, 'Tomatoes crushed during delivery', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM003' AND dr.code = 'TRANSPORT' AND u.username = 'warehouse_mgr'
ON CONFLICT (damage_number) DO NOTHING;

-- D.2: Damage due to Contamination
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-004', b.id, i.id, 3, 120.00, 360.00, dr.id, 'Cheese contaminated - mold found', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'MAIN' AND i.code = 'ITM007' AND dr.code = 'CONTAMINATION' AND u.username = 'warehouse_mgr'
ON CONFLICT (damage_number) DO NOTHING;

-- D.3: Damage due to Heat at Branch
INSERT INTO damages (damage_number, branch_id, item_id, quantity, unit_cost, total_cost, reason_id, description, status, registered_by, registered_at)
SELECT 'DMG-2024-005', b.id, i.id, 10, 8.00, 80.00, dr.id, 'Pepsi bottles exploded due to heat', 'pending', u.id, CURRENT_TIMESTAMP
FROM branches b, items i, damage_reasons dr, users u
WHERE b.code = 'BR001' AND i.code = 'ITM008' AND dr.code = 'HEAT' AND u.username = 'branch1_sup'
ON CONFLICT (damage_number) DO NOTHING;

-- D.4: Approve some damages
UPDATE damages SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE damage_number IN ('DMG-2024-003', 'DMG-2024-004');

-- D.5: Reject one damage (needs more investigation)
UPDATE damages SET 
    status = 'rejected',
    rejected_by = (SELECT id FROM users WHERE username = 'admin'),
    rejected_at = CURRENT_TIMESTAMP,
    rejection_reason = 'Need photos and more details before approval'
WHERE damage_number = 'DMG-2024-005';

-- D.6: Deduct approved damages from inventory
UPDATE inventory SET quantity = quantity - 5 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM003');

UPDATE inventory SET quantity = quantity - 3 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM007');

-- D.7: Record damage transactions
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'damage', 5, 50, 45, 15.00, 'damage', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM003' AND u.username = 'warehouse_mgr';

INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'damage', 3, 15, 12, 120.00, 'damage', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM007' AND u.username = 'warehouse_mgr';


-- =====================================================
-- SCENARIO E: Multiple Supplier Returns
-- Testing returns from different supplies
-- =====================================================

-- E.1: Return from SUP-2024-003 (Quality Issue)
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at)
SELECT 'RET-2024-002', sup.id, s.id, i.id, 10, 78.00, 780.00, 'Quality below standard', 'Chicken color was off', 'pending', u.id, CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i, users u
WHERE sup.supply_number = 'SUP-2024-003' AND s.code = 'SUP001' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr'
ON CONFLICT (return_number) DO NOTHING;

-- E.2: Return from SUP-2024-002 (Wrong Items)
INSERT INTO supplier_returns (return_number, supply_id, supplier_id, item_id, quantity, unit_price, total_amount, reason, description, status, registered_by, registered_at)
SELECT 'RET-2024-003', sup.id, s.id, i.id, 15, 14.00, 210.00, 'Wrong variety delivered', 'Ordered Roma tomatoes, received regular', 'pending', u.id, CURRENT_TIMESTAMP
FROM supplies sup, suppliers s, items i, users u
WHERE sup.supply_number = 'SUP-2024-002' AND s.code = 'SUP002' AND i.code = 'ITM003' AND u.username = 'warehouse_mgr'
ON CONFLICT (return_number) DO NOTHING;

-- E.3: Approve first return
UPDATE supplier_returns SET 
    status = 'approved',
    approved_by = (SELECT id FROM users WHERE username = 'admin'),
    approved_at = CURRENT_TIMESTAMP
WHERE return_number = 'RET-2024-002';

-- E.4: Update inventory and supplier balance for approved return
UPDATE inventory SET quantity = quantity - 10 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM001');

UPDATE suppliers SET current_balance = current_balance - 780.00 WHERE code = 'SUP001';

-- E.5: Record return transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'return', 10, 80, 70, 78.00, 'supplier_return', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM001' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO F: Full Day POS Operations
-- Multiple orders with different statuses
-- =====================================================

-- F.1: Order 2 - Dine In (Completed)
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, subtotal, tax_amount, total_amount, payment_method, status, cashier_id, created_at, paid_at, sent_to_kitchen_at, ready_at, delivered_at)
SELECT 'ORD-2024-002', b.id, 'dine_in', 'Mohamed Hassan', '01200000002', 205.00, 28.70, 233.70, 'visa', 'delivered', u.id, 
       CURRENT_TIMESTAMP - INTERVAL '2 hours',
       CURRENT_TIMESTAMP - INTERVAL '2 hours',
       CURRENT_TIMESTAMP - INTERVAL '115 minutes',
       CURRENT_TIMESTAMP - INTERVAL '90 minutes',
       CURRENT_TIMESTAMP - INTERVAL '85 minutes'
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'cashier1'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 2, 85.00, 170.00, 'delivered'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-002' AND mi.code = 'MENU001';

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 1, 15.00, 15.00, 'delivered'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-002' AND mi.code = 'MENU004';

-- F.2: Order 3 - Takeaway (In Kitchen)
INSERT INTO orders (order_number, branch_id, order_type, customer_name, customer_phone, subtotal, tax_amount, total_amount, payment_method, status, cashier_id, chef_id, created_at, paid_at, sent_to_kitchen_at, preparation_started_at)
SELECT 'ORD-2024-003', b.id, 'takeaway', 'Sara Ali', '01200000003', 170.00, 23.80, 193.80, 'cash', 'preparing', 
       (SELECT id FROM users WHERE username = 'cashier1'),
       (SELECT id FROM users WHERE username = 'chef1'),
       CURRENT_TIMESTAMP - INTERVAL '30 minutes',
       CURRENT_TIMESTAMP - INTERVAL '30 minutes',
       CURRENT_TIMESTAMP - INTERVAL '28 minutes',
       CURRENT_TIMESTAMP - INTERVAL '25 minutes'
FROM branches b WHERE b.code = 'BR001'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 2, 85.00, 170.00, 'preparing'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-003' AND mi.code = 'MENU001';

-- F.3: Order 4 - New Order (Just Created)
INSERT INTO orders (order_number, branch_id, order_type, customer_name, subtotal, tax_amount, total_amount, status, cashier_id, created_at)
SELECT 'ORD-2024-004', b.id, 'dine_in', 'Walk-in Customer', 100.00, 14.00, 114.00, 'new', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'cashier1'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 1, 85.00, 85.00, 'pending'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-004' AND mi.code = 'MENU001';

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 1, 15.00, 15.00, 'pending'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-004' AND mi.code = 'MENU004';

-- F.4: Order 5 - Cancelled Order
INSERT INTO orders (order_number, branch_id, order_type, customer_name, subtotal, tax_amount, total_amount, status, cashier_id, created_at, cancelled_at, cancelled_by, cancellation_reason)
SELECT 'ORD-2024-005', b.id, 'takeaway', 'Cancelled Customer', 85.00, 11.90, 96.90, 'cancelled', u.id, 
       CURRENT_TIMESTAMP - INTERVAL '1 hour',
       CURRENT_TIMESTAMP - INTERVAL '55 minutes',
       u.id,
       'Customer changed mind'
FROM branches b, users u WHERE b.code = 'BR001' AND u.username = 'cashier1'
ON CONFLICT (order_number) DO NOTHING;

-- F.5: Record consumption for completed orders
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, reference_type, created_by)
SELECT b.id, i.id, 'consumption', 0.5, 9.5, 9.0, 'order', u.id
FROM branches b, items i, users u WHERE b.code = 'BR001' AND i.code = 'ITM001' AND u.username = 'cashier1';

-- =====================================================
-- SCENARIO G: End of Day Inventory Count
-- Morning vs Evening count with variance analysis
-- =====================================================

-- G.1: Evening Count for Branch 1
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at)
SELECT b.id, CURRENT_DATE, 'evening', 'submitted', 'End of day count', u.id, CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'BR001' AND u.username = 'branch1_sup';

-- G.2: Add Evening Count Items (with variances)
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 9.0, 8.5, 'Possible theft or miscounting'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'evening' AND i.code = 'ITM001';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 5, 5, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'evening' AND i.code = 'ITM002';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 18, 17, 'Used for staff meal'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'evening' AND i.code = 'ITM003';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 48, 45, 'Some bottles broken'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR001' AND dic.count_type = 'evening' AND i.code = 'ITM008';

-- G.3: Morning Count for Main Warehouse
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at, approved_by, approved_at)
SELECT b.id, CURRENT_DATE, 'morning', 'approved', 'Opening count - all items verified', u.id, CURRENT_TIMESTAMP,
       (SELECT id FROM users WHERE username = 'admin'), CURRENT_TIMESTAMP
FROM branches b, users u
WHERE b.code = 'MAIN' AND u.username = 'warehouse_mgr';

-- G.4: Add Morning Count Items for Main Warehouse
INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 70, 70, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'MAIN' AND dic.count_type = 'morning' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM001';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 30, 30, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'MAIN' AND dic.count_type = 'morning' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM002';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 45, 44, 'One bag damaged'
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'MAIN' AND dic.count_type = 'morning' AND dic.count_date = CURRENT_DATE AND i.code = 'ITM003';

-- =====================================================
-- SCENARIO H: Inventory Adjustments
-- Manual adjustments for discrepancies
-- =====================================================

-- H.1: Positive Adjustment (Found extra stock)
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, notes, reference_type, created_by)
SELECT b.id, i.id, 'adjustment', 5, 40, 45, 'Found extra stock during reorganization', 'adjustment', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM004' AND u.username = 'warehouse_mgr';

UPDATE inventory SET quantity = 45 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM004');

-- H.2: Negative Adjustment (Stock discrepancy)
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, notes, reference_type, created_by)
SELECT b.id, i.id, 'adjustment', -2, 150, 148, 'Discrepancy found during audit', 'adjustment', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM006' AND u.username = 'warehouse_mgr';

UPDATE inventory SET quantity = 148 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM006');

-- =====================================================
-- SCENARIO I: Complex Notifications
-- Different notification types and priorities
-- =====================================================

-- I.1: Critical Low Stock Alert
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'low_stock', 'CRITICAL: Stock Depleted', 'Beef Meat stock is critically low (only 30 units)', 'high', 'inventory', FALSE
FROM users u, branches b WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- I.2: Expiry Warning (Multiple Items)
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'expiry_warning', 'Items Expiring Soon', '3 batches will expire within 7 days. Please review.', 'high', 'inventory', FALSE
FROM users u, branches b WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- I.3: Pending Approval Reminder
INSERT INTO notifications (user_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, 'pending_approval', 'Pending Approvals', 'You have 3 pending damage reports awaiting approval', 'normal', 'damage', FALSE
FROM users u WHERE u.username = 'admin';

-- I.4: Transfer Received Notification
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'transfer_received', 'Transfer Received', 'Transfer TRF-2024-001 has been received at Branch 1', 'normal', 'transfer', TRUE
FROM users u, branches b WHERE u.username = 'warehouse_mgr' AND b.code = 'MAIN';

-- I.5: Order Alert for Kitchen
INSERT INTO notifications (user_id, branch_id, type, title, message, priority, reference_type, is_read)
SELECT u.id, b.id, 'new_order', 'New Order Received', 'Order ORD-2024-004 is waiting in queue', 'high', 'order', FALSE
FROM users u, branches b WHERE u.username = 'chef1' AND b.code = 'BR001';

-- I.6: System Alert
INSERT INTO notifications (user_id, type, title, message, priority, is_read, expires_at)
SELECT u.id, 'system', 'System Maintenance', 'Scheduled maintenance tonight at 2 AM', 'normal', FALSE, CURRENT_TIMESTAMP + INTERVAL '12 hours'
FROM users u WHERE u.username = 'admin';

-- =====================================================
-- SCENARIO J: Comprehensive Audit Trail
-- Tracking all important actions
-- =====================================================

-- J.1: User Login Audit
INSERT INTO audit_logs (user_id, action, table_name, ip_address, user_agent)
SELECT u.id, 'LOGIN', 'users', '192.168.1.100', 'Mozilla/5.0 Chrome/120.0'
FROM users u WHERE u.username = 'admin';

INSERT INTO audit_logs (user_id, action, table_name, ip_address, user_agent)
SELECT u.id, 'LOGIN', 'users', '192.168.1.101', 'Mozilla/5.0 Chrome/120.0'
FROM users u WHERE u.username = 'cashier1';

-- J.2: Supply Creation Audit
INSERT INTO audit_logs (user_id, action, table_name, record_id, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplies', sup.id, 
       '{"supply_number": "SUP-2024-003", "total_amount": 9120, "supplier": "SUP001"}'::jsonb,
       '192.168.1.100'
FROM users u, supplies sup WHERE u.username = 'warehouse_mgr' AND sup.supply_number = 'SUP-2024-003';

-- J.3: Damage Approval Audit
INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'damages', d.id,
       '{"status": "pending"}'::jsonb,
       '{"status": "approved", "approved_by": "admin"}'::jsonb,
       '192.168.1.100'
FROM users u, damages d WHERE u.username = 'admin' AND d.damage_number = 'DMG-2024-003';

-- J.4: Payment Audit
INSERT INTO audit_logs (user_id, action, table_name, record_id, new_values, ip_address)
SELECT u.id, 'CREATE', 'supplier_payments', sp.id,
       '{"payment_number": "PAY-2024-002", "amount": 5000, "method": "bank_transfer"}'::jsonb,
       '192.168.1.100'
FROM users u, supplier_payments sp WHERE u.username = 'admin' AND sp.payment_number = 'PAY-2024-002';

-- J.5: Order Status Change Audit
INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'orders', o.id,
       '{"status": "new"}'::jsonb,
       '{"status": "delivered"}'::jsonb,
       '192.168.1.101'
FROM users u, orders o WHERE u.username = 'cashier1' AND o.order_number = 'ORD-2024-002';

-- J.6: Inventory Adjustment Audit
INSERT INTO audit_logs (user_id, action, table_name, old_values, new_values, ip_address)
SELECT u.id, 'UPDATE', 'inventory',
       '{"item": "ITM004", "quantity": 40}'::jsonb,
       '{"item": "ITM004", "quantity": 45, "reason": "Found extra stock"}'::jsonb,
       '192.168.1.100'
FROM users u WHERE u.username = 'warehouse_mgr';


-- =====================================================
-- SCENARIO K: Branch 2 Setup and Operations
-- Complete setup for second branch
-- =====================================================

-- K.1: Create Users for Branch 2
INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP006', 'branch2_sup', 'branch2@restaurant.com', 'hashed_password_123', 'Khaled Omar', 'Khaled Omar', '01000000006',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'branch_supervisor' AND b.code = 'BR002'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP007', 'cashier2', 'cashier2@restaurant.com', 'hashed_password_123', 'Nour Mohamed', 'Nour Mohamed', '01000000007',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'cashier' AND b.code = 'BR002'
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (employee_code, username, email, password_hash, full_name, full_name_ar, phone, role_id, branch_id, status)
SELECT 'EMP008', 'chef2', 'chef2@restaurant.com', 'hashed_password_123', 'Youssef Ahmed', 'Youssef Ahmed', '01000000008',
       r.id, b.id, 'active'
FROM roles r, branches b WHERE r.name = 'chef' AND b.code = 'BR002'
ON CONFLICT (username) DO NOTHING;

-- K.2: Initialize Inventory for Branch 2 (from approved transfer)
INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 25, 15 FROM branches b, items i WHERE b.code = 'BR002' AND i.code = 'ITM001'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 25;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 10, 8 FROM branches b, items i WHERE b.code = 'BR002' AND i.code = 'ITM002'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 10;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 30, 25 FROM branches b, items i WHERE b.code = 'BR002' AND i.code = 'ITM003'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 30;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 50, 30 FROM branches b, items i WHERE b.code = 'BR002' AND i.code = 'ITM006'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 50;

INSERT INTO inventory (branch_id, item_id, quantity, min_quantity)
SELECT b.id, i.id, 80, 50 FROM branches b, items i WHERE b.code = 'BR002' AND i.code = 'ITM008'
ON CONFLICT ON CONSTRAINT uk_inventory_branch_item DO UPDATE SET quantity = 80;

-- K.3: Orders for Branch 2
INSERT INTO orders (order_number, branch_id, order_type, customer_name, subtotal, tax_amount, total_amount, payment_method, status, cashier_id, created_at, paid_at, sent_to_kitchen_at, ready_at, delivered_at)
SELECT 'ORD-2024-006', b.id, 'dine_in', 'Branch 2 Customer 1', 185.00, 25.90, 210.90, 'cash', 'delivered', u.id,
       CURRENT_TIMESTAMP - INTERVAL '3 hours',
       CURRENT_TIMESTAMP - INTERVAL '3 hours',
       CURRENT_TIMESTAMP - INTERVAL '175 minutes',
       CURRENT_TIMESTAMP - INTERVAL '150 minutes',
       CURRENT_TIMESTAMP - INTERVAL '145 minutes'
FROM branches b, users u WHERE b.code = 'BR002' AND u.username = 'cashier2'
ON CONFLICT (order_number) DO NOTHING;

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 2, 85.00, 170.00, 'delivered'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-006' AND mi.code = 'MENU001';

INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, total_price, status)
SELECT o.id, mi.id, 1, 15.00, 15.00, 'delivered'
FROM orders o, menu_items mi WHERE o.order_number = 'ORD-2024-006' AND mi.code = 'MENU004';

-- K.4: Branch 2 Daily Count
INSERT INTO daily_inventory_counts (branch_id, count_date, count_type, status, notes, counted_by, submitted_at)
SELECT b.id, CURRENT_DATE, 'morning', 'submitted', 'Branch 2 opening count', u.id, CURRENT_TIMESTAMP
FROM branches b, users u WHERE b.code = 'BR002' AND u.username = 'branch2_sup';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 25, 25, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR002' AND i.code = 'ITM001';

INSERT INTO daily_inventory_count_items (count_id, item_id, system_quantity, actual_quantity, variance_reason)
SELECT dic.id, i.id, 10, 10, NULL
FROM daily_inventory_counts dic, items i, branches b
WHERE dic.branch_id = b.id AND b.code = 'BR002' AND i.code = 'ITM002';

-- K.5: Branch Settings for Branch 2
INSERT INTO branch_settings (branch_id, key, value, updated_by)
SELECT b.id, 'receipt_header', 'Welcome to Branch 2', u.id
FROM branches b, users u WHERE b.code = 'BR002' AND u.username = 'admin'
ON CONFLICT ON CONSTRAINT uk_branch_setting DO NOTHING;

INSERT INTO branch_settings (branch_id, key, value, updated_by)
SELECT b.id, 'receipt_footer', 'Thank you! Visit again!', u.id
FROM branches b, users u WHERE b.code = 'BR002' AND u.username = 'admin'
ON CONFLICT ON CONSTRAINT uk_branch_setting DO NOTHING;

INSERT INTO branch_settings (branch_id, key, value, updated_by)
SELECT b.id, 'kitchen_printer', 'PRINTER-BR2-001', u.id
FROM branches b, users u WHERE b.code = 'BR002' AND u.username = 'admin'
ON CONFLICT ON CONSTRAINT uk_branch_setting DO NOTHING;

-- =====================================================
-- SCENARIO L: More Menu Items and Ingredients
-- Complete menu setup
-- =====================================================

-- L.1: Add More Menu Items
INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU005', 'Beef Burger', 'Beef Burger', 'Grilled beef burger with cheese', mc.id, 75.00, 40.00, 14, 15, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT002'
ON CONFLICT (code) DO NOTHING;

INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU006', 'Mixed Grill', 'Mixed Grill', 'Assorted grilled meats', mc.id, 180.00, 100.00, 14, 30, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT001'
ON CONFLICT (code) DO NOTHING;

INSERT INTO menu_items (code, name, name_ar, description, category_id, price, cost, tax_percent, preparation_time_minutes, is_available, is_active)
SELECT 'MENU007', 'Rice Meal', 'Rice Meal', 'Rice with vegetables', mc.id, 45.00, 20.00, 14, 15, TRUE, TRUE
FROM menu_categories mc WHERE mc.code = 'MCAT003'
ON CONFLICT (code) DO NOTHING;

-- L.2: Add Ingredients for New Menu Items
INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.150, u.id, FALSE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU005' AND i.code = 'ITM002' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.050, u.id, TRUE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU005' AND i.code = 'ITM007' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.200, u.id, FALSE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU006' AND i.code = 'ITM001' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.200, u.id, FALSE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU006' AND i.code = 'ITM002' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.150, u.id, FALSE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU007' AND i.code = 'ITM006' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.050, u.id, FALSE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU007' AND i.code = 'ITM003' AND u.code = 'KG';

INSERT INTO menu_item_ingredients (menu_item_id, item_id, quantity, unit_id, is_optional)
SELECT mi.id, i.id, 0.030, u.id, FALSE
FROM menu_items mi, items i, units u WHERE mi.code = 'MENU007' AND i.code = 'ITM004' AND u.code = 'KG';

-- =====================================================
-- SCENARIO M: Supply from New Supplier (SUP003 - Dairy)
-- =====================================================

-- M.1: Create Supply
INSERT INTO supplies (supply_number, supplier_id, branch_id, invoice_number, invoice_date, subtotal, tax_amount, total_amount, payment_method, payment_status, received_by, received_at)
SELECT 'SUP-2024-004', s.id, b.id, 'INV-004', CURRENT_DATE, 2400.00, 336.00, 2736.00, 'credit', 'pending', u.id, CURRENT_TIMESTAMP
FROM suppliers s, branches b, users u
WHERE s.code = 'SUP003' AND b.code = 'MAIN' AND u.username = 'warehouse_mgr'
ON CONFLICT (supply_number) DO NOTHING;

-- M.2: Supply Items
INSERT INTO supply_items (supply_id, item_id, quantity, received_quantity, unit_price, tax_percent, total_price, batch_number, expiry_date)
SELECT sup.id, i.id, 20, 20, 120.00, 14, 2736.00, 'BATCH-007', CURRENT_DATE + INTERVAL '30 days'
FROM supplies sup, items i WHERE sup.supply_number = 'SUP-2024-004' AND i.code = 'ITM007';

-- M.3: Update Supplier Balance
UPDATE suppliers SET current_balance = current_balance + 2736.00 WHERE code = 'SUP003';

-- M.4: Update Inventory
UPDATE inventory SET quantity = quantity + 20 
WHERE branch_id = (SELECT id FROM branches WHERE code = 'MAIN') 
AND item_id = (SELECT id FROM items WHERE code = 'ITM007');

-- M.5: Add Batch
INSERT INTO inventory_batches (inventory_id, batch_number, quantity, remaining_quantity, purchase_price, expiry_date, received_date, supply_id)
SELECT inv.id, 'BATCH-007', 20, 20, 120.00, CURRENT_DATE + INTERVAL '30 days', CURRENT_DATE, sup.id
FROM inventory inv
JOIN branches b ON inv.branch_id = b.id
JOIN items i ON inv.item_id = i.id
JOIN supplies sup ON sup.supply_number = 'SUP-2024-004'
WHERE b.code = 'MAIN' AND i.code = 'ITM007';

-- M.6: Record Transaction
INSERT INTO inventory_transactions (branch_id, item_id, operation_type, quantity, quantity_before, quantity_after, unit_cost, reference_type, created_by)
SELECT b.id, i.id, 'supply', 20, 12, 32, 120.00, 'supply', u.id
FROM branches b, items i, users u WHERE b.code = 'MAIN' AND i.code = 'ITM007' AND u.username = 'warehouse_mgr';

-- =====================================================
-- SCENARIO N: User Sessions Management
-- =====================================================

-- N.1: Active Sessions
INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_ghi789', 'Chrome on Windows', '192.168.1.102', TRUE, CURRENT_TIMESTAMP + INTERVAL '24 hours', CURRENT_TIMESTAMP
FROM users u WHERE u.username = 'warehouse_mgr';

INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_jkl012', 'Safari on iPad', '192.168.1.103', TRUE, CURRENT_TIMESTAMP + INTERVAL '24 hours', CURRENT_TIMESTAMP
FROM users u WHERE u.username = 'branch1_sup';

INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_mno345', 'Chrome on Android', '192.168.1.104', TRUE, CURRENT_TIMESTAMP + INTERVAL '24 hours', CURRENT_TIMESTAMP
FROM users u WHERE u.username = 'chef1';

-- N.2: Expired/Inactive Sessions
INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_old001', 'Firefox on Windows', '192.168.1.50', FALSE, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '3 days'
FROM users u WHERE u.username = 'admin';

INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, is_active, expires_at, last_activity_at)
SELECT u.id, 'hash_token_old002', 'Chrome on Mac', '192.168.1.51', FALSE, CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '2 days'
FROM users u WHERE u.username = 'cashier1';
